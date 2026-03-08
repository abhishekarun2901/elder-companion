// lib/emergency_contact_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final DateTime createdAt;
  final bool isPrimary;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.createdAt,
    this.isPrimary = false,
  });

  factory EmergencyContact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyContact(
      id: doc.id,
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPrimary: data['isPrimary'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'createdAt': FieldValue.serverTimestamp(),
      'isPrimary': isPrimary,
    };
  }
}

class EmergencyContactScreen extends StatefulWidget {
  const EmergencyContactScreen({super.key});

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<List<EmergencyContact>> _contactsStream;

  @override
  void initState() {
    super.initState();
    _initializeContactsStream();
  }

  void _initializeContactsStream() {
    final user = _auth.currentUser;
    if (user != null) {
      _contactsStream = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('emergency_contacts')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        // Sort in memory by isPrimary first, then by createdAt
        final docs = snapshot.docs
            .map((doc) => EmergencyContact.fromFirestore(doc))
            .toList();
        docs.sort((a, b) {
          // Primary contacts first
          if (a.isPrimary && !b.isPrimary) return -1;
          if (!a.isPrimary && b.isPrimary) return 1;
          // Then by creation date (newest first)
          return b.createdAt.compareTo(a.createdAt);
        });
        return docs;
      });
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      await launchUrl(launchUri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch phone call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addOrEditContact({EmergencyContact? contact}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditContactScreen(contact: contact),
      ),
    );

    if (result != null && result is EmergencyContact) {
      await _saveContact(result, isEdit: contact != null);
    }
  }

  Future<void> _saveContact(EmergencyContact contact, {bool isEdit = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      if (isEdit) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('emergency_contacts')
            .doc(contact.id)
            .update({
          'name': contact.name,
          'phoneNumber': contact.phoneNumber,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('emergency_contacts')
            .add(contact.toFirestore());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving contact: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteContact(String contactId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('emergency_contacts')
          .doc(contactId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting contact: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _setPrimaryContact(String contactId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get all contacts
      final contactsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('emergency_contacts')
          .get();

      // Create batch write
      final batch = _firestore.batch();

      // Set all to false
      for (var doc in contactsSnapshot.docs) {
        batch.update(doc.reference, {'isPrimary': false});
      }

      // Set selected to true
      final selectedContactRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('emergency_contacts')
          .doc(contactId);
      batch.update(selectedContactRef, {'isPrimary': true});

      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primary contact updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating primary contact: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.red.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<EmergencyContact>>(
        stream: _contactsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final contacts = snapshot.data ?? [];

          if (contacts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_missed,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No emergency contacts added yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () => _addOrEditContact(),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Add First Contact',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return EmergencyContactCard(
                contact: contact,
                onCall: () => _makeCall(contact.phoneNumber),
                onEdit: () => _addOrEditContact(contact: contact),
                onDelete: () => _deleteContact(contact.id),
                onSetPrimary: () => _setPrimaryContact(contact.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditContact(),
        backgroundColor: Colors.red.shade700,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Contact',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// Contact card widget
class EmergencyContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetPrimary;

  const EmergencyContactCard({
    super.key,
    required this.contact,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
    required this.onSetPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: contact.isPrimary ? Colors.red.shade700 : Colors.grey.shade300,
              width: contact.isPrimary ? 5 : 2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              contact.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (contact.isPrimary)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Primary',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contact.phoneNumber,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onCall,
                    icon: const Icon(
                      Icons.call,
                      color: Colors.green,
                      size: 28,
                    ),
                    tooltip: 'Call',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!contact.isPrimary)
                    TextButton.icon(
                      onPressed: onSetPrimary,
                      icon: const Icon(Icons.star_border, size: 18),
                      label: const Text('Set Primary'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  if (contact.isPrimary)
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.star, size: 18),
                      label: const Text('Primary'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showDeleteConfirmation(context, onDelete),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Contact?'),
          content: Text(
            'Are you sure you want to delete ${contact.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

// Add/Edit contact screen
class AddEditContactScreen extends StatefulWidget {
  final EmergencyContact? contact;

  const AddEditContactScreen({super.key, this.contact});

  @override
  State<AddEditContactScreen> createState() => _AddEditContactScreenState();
}

class _AddEditContactScreenState extends State<AddEditContactScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.contact?.name ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.contact?.phoneNumber ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.contact != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Contact' : 'Add Emergency Contact',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.red.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contact Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., Mom, Dad, Sister',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.red.shade700,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a contact name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Phone Number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+91 9876543210',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.red.shade700,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  if (value.length < 10) {
                    return 'Phone number must be at least 10 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final contact = EmergencyContact(
                        id: widget.contact?.id ?? '',
                        name: _nameController.text,
                        phoneNumber: _phoneController.text,
                        createdAt: widget.contact?.createdAt ?? DateTime.now(),
                        isPrimary: widget.contact?.isPrimary ?? false,
                      );
                      Navigator.pop(context, contact);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                  child: Text(
                    isEdit ? 'Update Contact' : 'Add Contact',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}