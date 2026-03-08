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
        const SnackBar(content: Text('FATAL: User is not logged in!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // Data to be saved
      final profileData = {
        'uid': user.uid,
        'phoneNumber': user.phoneNumber,
        'role': 'elder', // Explicitly marking as elder
        'name': _nameController.text,
        'age': int.tryParse(_ageController.text) ?? 0,
        'caregiverName': _caregiverNameController.text,
        'caregiverPhone': '+91${_caregiverPhoneController.text.trim()}', // Standardize format for matching
        'emergencyContact': {
          'name': _emergencyNameController.text,
          'phone': _emergencyPhoneController.text,
        },
        'interests': _interestsController.text,
        'hobbies': _hobbiesController.text,
        'skills': _skillsController.text,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(profileData);

      // Navigate to home screen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
            (Route<dynamic> route) => false,
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile', style: TextStyle(fontSize: 28)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form( // Wrap UI with a Form widget
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //
              // CORRECT IMPLEMENTATION: Widgets are built here, inside the build method
              //
              _buildSectionTitle('Your Essential Details', Colors.teal),
              ElderFriendlyTextField(controller: _nameController, label: 'What is your full name?', isRequired: true),
              ElderFriendlyTextField(controller: _ageController, label: 'Your Age (Years)', keyboardType: TextInputType.number, isRequired: true),
              const SizedBox(height: 30),

              _buildSectionTitle('Caregiver Details', Colors.orange),
              ElderFriendlyTextField(controller: _caregiverNameController, label: 'Caregiver\'s Name', isRequired: true),
              ElderFriendlyTextField(controller: _caregiverPhoneController, label: 'Caregiver Phone (10-digit)', keyboardType: TextInputType.phone, isRequired: true),
              const SizedBox(height: 30),

              _buildSectionTitle('Emergency Contact', Colors.red),
              ElderFriendlyTextField(controller: _emergencyNameController, label: 'Emergency Person\'s Name', isRequired: true),
              ElderFriendlyTextField(controller: _emergencyPhoneController, label: 'Emergency Phone Number', keyboardType: TextInputType.phone, isRequired: true),
              const SizedBox(height: 30),

              _buildSectionTitle('Your Interests & Abilities', Colors.blue),
              ElderFriendlyTextField(controller: _hobbiesController, label: 'What are your hobbies?', maxLines: 3),
              ElderFriendlyTextField(controller: _skillsController, label: 'Do you have any practical skills?', maxLines: 3),
              ElderFriendlyTextField(controller: _interestsController, label: 'What topics interest you most?', maxLines: 3),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('SAVE AND CONTINUE', style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
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
        Text(title, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color)),
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
          Text('$label${isRequired ? " *" : ""}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8.0),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 28, color: Colors.black),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(20.0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(width: 2.0, color: Colors.teal)),
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