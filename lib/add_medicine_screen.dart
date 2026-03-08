import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/notification_service.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  
  TimeOfDay? _selectedTime;
  String? _editingDocId;
  int? _editingNotificationId;

  final user = FirebaseAuth.instance.currentUser;

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTime == null) {
         ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time')),
      );
      return;
    }
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in!')),
      );
      return;
    }

    // Calculate scheduled DateTime for today
    final now = DateTime.now();
    DateTime scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDateTime.isBefore(now)) {
      scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
    }

    int notificationId = _editingNotificationId ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    notificationId = notificationId & 0x7FFFFFFF;

    try {
      // If editing, cancel the old notification first (to be clean, though overwriting same ID works if ID reused)
      // Actually if we reuse ID, zonedSchedule overwrites. But let's be safe.
      if (_editingDocId != null) {
           await NotificationService().cancelNotification(notificationId);
      }

      final medicineData = {
        'elderId': user!.uid,
        'medicineName': _nameController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'time': _selectedTime!.format(context),
        'hour': _selectedTime!.hour,
        'minute': _selectedTime!.minute,
        'notes': _notesController.text.trim(),
        'notificationId': notificationId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_editingDocId != null) {
        await FirebaseFirestore.instance
            .collection('medicines')
            .doc(_editingDocId)
            .update(medicineData);
      } else {
        await FirebaseFirestore.instance.collection('medicines').add(medicineData);
      }

       // Schedule Daily Notification
      await NotificationService().scheduleNotification(
        id: notificationId,
        title: "Medicine Time!",
        body: "Please take ${_nameController.text} (${_dosageController.text})",
        scheduledTime: scheduledDateTime,
        matchDateTimeComponents: DateTimeComponents.time, // Daily
      );

      _resetForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editingDocId != null ? 'Medicine Updated' : 'Medicine Added')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving medicine: $e')),
      );
    }
  }

  void _resetForm() {
    _nameController.clear();
    _dosageController.clear();
    _notesController.clear();
    setState(() {
        _selectedTime = null;
        _editingDocId = null;
        _editingNotificationId = null;
    });
  }

  Future<void> _deleteMedicine(String docId, int? notificationId) async {
      await FirebaseFirestore.instance.collection('medicines').doc(docId).delete();
      if (notificationId != null) {
          await NotificationService().cancelNotification(notificationId);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine deleted')),
      );
  }

  void _startEdit(Map<String, dynamic> data, String docId) {
      setState(() {
          _editingDocId = docId;
          _nameController.text = data['medicineName'];
          _dosageController.text = data['dosage'];
          _notesController.text = data['notes'] ?? '';
          _editingNotificationId = data['notificationId'];
          
          if (data['hour'] != null && data['minute'] != null) {
              _selectedTime = TimeOfDay(hour: data['hour'], minute: data['minute']);
          } else {
              // Fallback if legacy data doesn't have hour/minute
              _selectedTime = null; 
          }
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editingDocId != null ? 'Edit Medicine' : 'Add Medicine')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------- ADD MEDICINE FORM ----------
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration:
                        const InputDecoration(labelText: 'Medicine Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _dosageController,
                    decoration:
                        const InputDecoration(labelText: 'Dosage (e.g. 500mg)'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  
                  // Time Picker Button
                  SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _selectTime(context),
                        child: Text(_selectedTime == null 
                            ? 'Select Time (Daily)' 
                            : 'Time: ${_selectedTime!.format(context)}'),
                      ),
                  ),

                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notesController,
                    decoration:
                        const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                        if (_editingDocId != null) 
                            Expanded(child: TextButton(onPressed: _resetForm, child: const Text("Cancel Edit"))),
                        Expanded(
                            child: ElevatedButton(
                            onPressed: _saveMedicine,
                            child: Text(_editingDocId != null ? 'Update Medicine' : 'Save Medicine'),
                            ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---------- MEDICINE LIST ----------
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Added Medicines",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('medicines')
                    .where('elderId', isEqualTo: user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('No medicines added yet'));
                  }

                  final docs = snapshot.data!.docs;
                  docs.sort((a, b) {
                      final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      if (aTime == null || bTime == null) return 0;
                      return bTime.compareTo(aTime);
                  });

                  return ListView(
                    children: docs.map((doc) {
                      final data =
                          doc.data() as Map<String, dynamic>;
                      final docId = doc.id;

                      return Card(
                        child: ListTile(
                          leading:
                              const Icon(Icons.medication_outlined, color: Colors.teal),
                          title: Text(data['medicineName']),
                          subtitle: Text(
                              '${data['dosage']} • ${data['time']}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                                if (value == 'edit') {
                                    _startEdit(data, docId);
                                } else if (value == 'delete') {
                                    _deleteMedicine(docId, data['notificationId']);
                                }
                            },
                            itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
