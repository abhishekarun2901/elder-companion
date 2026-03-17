import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart'; // Import HomeScreen for navigation

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  _ProfileDetailsScreenState createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  // Add a form key and controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  // Caregiver Details
  final _caregiverNameController = TextEditingController();
  final _caregiverPhoneController = TextEditingController();

  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _hobbiesController = TextEditingController();
  final _skillsController = TextEditingController();
  final _interestsController = TextEditingController();

  bool _isLoading = false;
  bool _isFetching = true; // Added to show loading while fetching data
  String _preferredLanguage = 'auto';

  String? _normalizePhone(String? value) {
    final input = (value ?? '').trim();
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (input.startsWith('+') && digits.length >= 10 && digits.length <= 15) {
      return '+$digits';
    }
    if (digits.length == 10) {
      return '+91$digits';
    }
    if (digits.length >= 11 && digits.length <= 15) {
      return '+$digits';
    }
    return null;
  }

  String _displayPhone(String? value) {
    final normalized = _normalizePhone(value);
    if (normalized == null) {
      return (value ?? '').trim();
    }
    return normalized.startsWith('+91') && normalized.length == 13
        ? normalized.substring(3)
        : normalized;
  }

  Future<void> _syncEmergencyContactCollection({
    required String uid,
    required String name,
    required String phone,
  }) async {
    final contactsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('emergency_contacts');

    final existingPrimary = await contactsRef
        .where('isPrimary', isEqualTo: true)
        .limit(1)
        .get();

    if (existingPrimary.docs.isNotEmpty) {
      await existingPrimary.docs.first.reference.set({
        'name': name,
        'phoneNumber': phone,
        'isPrimary': true,
      }, SetOptions(merge: true));
      return;
    }

    final matchingPhone = await contactsRef
        .where('phoneNumber', isEqualTo: phone)
        .limit(1)
        .get();

    if (matchingPhone.docs.isNotEmpty) {
      await matchingPhone.docs.first.reference.set({
        'name': name,
        'phoneNumber': phone,
        'isPrimary': true,
      }, SetOptions(merge: true));
      return;
    }

    await contactsRef.add({
      'name': name,
      'phoneNumber': phone,
      'createdAt': FieldValue.serverTimestamp(),
      'isPrimary': true,
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isFetching = false);
      return;
    }

    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _ageController.text = (data['age'] ?? '').toString();
          
          _caregiverNameController.text = data['caregiverName'] ?? '';
          
          // Remove the +91 prefix for the UI if it exists, since the UI expects 10 digits
          _caregiverPhoneController.text =
              _displayPhone(data['caregiverPhone']?.toString());

          if (data['emergencyContact'] != null) {
            _emergencyNameController.text = data['emergencyContact']['name'] ?? '';
            _emergencyPhoneController.text = _displayPhone(
              data['emergencyContact']['phone']?.toString(),
            );
          }

          _hobbiesController.text = data['hobbies'] ?? '';
          _skillsController.text = data['skills'] ?? '';
          _interestsController.text = data['interests'] ?? '';
          _preferredLanguage = (data['preferredLanguage'] ?? 'auto').toString();
        });
      }
    } catch (e) {
      debugPrint("Error loading profile data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  @override
  void dispose() {
    // Dispose controllers
    _nameController.dispose();
    _ageController.dispose();
    _caregiverNameController.dispose();
    _caregiverPhoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _hobbiesController.dispose();
    _skillsController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  // Function to save data to Firestore
  // In lib/profile_details_screen.dart

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FATAL: User is not logged in!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final caregiverPhone = _normalizePhone(_caregiverPhoneController.text);
      final emergencyPhone = _normalizePhone(_emergencyPhoneController.text);

      if (caregiverPhone == null || emergencyPhone == null) {
        throw Exception(
          'Enter valid caregiver and emergency phone numbers with country code or 10 digits.',
        );
      }

      // Data to be saved
      final profileData = {
        'uid': user.uid,
        'phoneNumber': user.phoneNumber,
        'email': user.email,
        'authProviderIds': user.providerData
            .map((provider) => provider.providerId)
            .toList(),
        'role': 'elder', // Explicitly marking as elder
        'name': _nameController.text,
        'age': int.tryParse(_ageController.text) ?? 0,
        'caregiverName': _caregiverNameController.text.trim(),
        'caregiverPhone': caregiverPhone,
        'emergencyContact': {
          'name': _emergencyNameController.text.trim(),
          'phone': emergencyPhone,
        },
        'interests': _interestsController.text,
        'hobbies': _hobbiesController.text,
        'skills': _skillsController.text,
        'preferredLanguage': _preferredLanguage,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profileData);

      await _syncEmergencyContactCollection(
        uid: user.uid,
        name: _emergencyNameController.text.trim(),
        phone: emergencyPhone,
      );

      // Navigate to home screen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(fontSize: 28),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: _isFetching 
          ? const Center(child: CircularProgressIndicator())
          : Form(
          // Wrap UI with a Form widget
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //
              // CORRECT IMPLEMENTATION: Widgets are built here, inside the build method
              //
              _buildSectionTitle('Your Essential Details', Colors.teal),
              ElderFriendlyTextField(
                controller: _nameController,
                label: 'What is your full name?',
                isRequired: true,
              ),
              ElderFriendlyTextField(
                controller: _ageController,
                label: 'Your Age (Years)',
                keyboardType: TextInputType.number,
                isRequired: true,
              ),
              const SizedBox(height: 30),

              _buildSectionTitle('Caregiver Details', Colors.orange),
              ElderFriendlyTextField(
                controller: _caregiverNameController,
                label: 'Caregiver\'s Name',
                isRequired: true,
              ),
              ElderFriendlyTextField(
                controller: _caregiverPhoneController,
                label: 'Caregiver Phone (10-digit)',
                keyboardType: TextInputType.phone,
                isRequired: true,
              ),
              const SizedBox(height: 30),

              _buildSectionTitle('Emergency Contact', Colors.red),
              ElderFriendlyTextField(
                controller: _emergencyNameController,
                label: 'Emergency Person\'s Name',
                isRequired: true,
              ),
              ElderFriendlyTextField(
                controller: _emergencyPhoneController,
                label: 'Emergency Phone Number',
                keyboardType: TextInputType.phone,
                isRequired: true,
              ),
              const SizedBox(height: 30),

              _buildSectionTitle('Your Interests & Abilities', Colors.blue),
              DropdownButtonFormField<String>(
                initialValue: _preferredLanguage,
                decoration: const InputDecoration(
                  labelText: 'Preferred Language',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Auto (EN/ML)')),
                  DropdownMenuItem(value: 'en-US', child: Text('English')),
                  DropdownMenuItem(value: 'ml-IN', child: Text('Malayalam')),
                ],
                onChanged: (v) {
                  setState(() {
                    _preferredLanguage = v ?? 'auto';
                  });
                },
              ),
              const SizedBox(height: 16),
              ElderFriendlyTextField(
                controller: _hobbiesController,
                label: 'What are your hobbies?',
                maxLines: 3,
              ),
              ElderFriendlyTextField(
                controller: _skillsController,
                label: 'Do you have any practical skills?',
                maxLines: 3,
              ),
              ElderFriendlyTextField(
                controller: _interestsController,
                label: 'What topics interest you most?',
                maxLines: 3,
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 80,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'SAVE AND CONTINUE',
                          style: TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Divider(thickness: 3, color: color),
      ],
    );
  }
}

// --- Custom Widget for Large Input Field (MODIFIED) ---
class ElderFriendlyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final bool isRequired;
  final int maxLines;

  const ElderFriendlyTextField({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.isRequired = false,
    this.maxLines = 1,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label${isRequired ? " *" : ""}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8.0),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 28, color: Colors.black),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(20.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(width: 2.0, color: Colors.teal),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: (value) {
              if (isRequired && (value == null || value.isEmpty)) {
                return 'This field cannot be empty';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
