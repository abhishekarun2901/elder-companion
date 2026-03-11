import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/notification_service.dart';

class AddMedicineScreen extends StatefulWidget {
  final String? targetElderId;

  const AddMedicineScreen({super.key, this.targetElderId});

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
  List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7];
  final List<String> _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a time')));
      return;
    }
    final elderIdToUse = widget.targetElderId ?? user?.uid;
    if (elderIdToUse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot determine Elder ID!')),
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

    int notificationId =
        _editingNotificationId ??
        ((DateTime.now().millisecondsSinceEpoch ~/ 1000) % 100000000); // keep it small enough to add +7 without overflow

    try {
      if (_editingDocId != null && _editingNotificationId != null) {
        for (int i = 1; i <= 7; i++) {
          await NotificationService().cancelNotification(_editingNotificationId! + i);
        }
        await NotificationService().cancelNotification(_editingNotificationId!);
      }

      final medicineData = {
        'elderId': elderIdToUse,
        'medicineName': _nameController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'time': _selectedTime!.format(context),
        'hour': _selectedTime!.hour,
        'minute': _selectedTime!.minute,
        'selectedDays': _selectedDays,
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
        await FirebaseFirestore.instance
            .collection('medicines')
            .add(medicineData);
      }

      // Schedule notifications for each selected day
      if (widget.targetElderId == null) {
        for (int day in _selectedDays) {
          int daysUntil = day - now.weekday;
          DateTime scheduleForDay = DateTime(
            now.year, now.month, now.day, _selectedTime!.hour, _selectedTime!.minute
          );

          if (daysUntil < 0 || (daysUntil == 0 && scheduleForDay.isBefore(now))) {
            daysUntil += 7; // Next week
          }
          
          scheduleForDay = scheduleForDay.add(Duration(days: daysUntil));

          await NotificationService().scheduleNotification(
            id: notificationId + day,
            title: "Medicine Time!",
            body: "Please take ${_nameController.text} (${_dosageController.text})",
            scheduledTime: scheduleForDay,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, 
          );
        }
      }

      _resetForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingDocId != null ? 'Medicine Updated' : 'Medicine Added',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving medicine: $e')));
    }
  }

  void _resetForm() {
    _nameController.clear();
    _dosageController.clear();
    _notesController.clear();
    setState(() {
      _selectedTime = null;
      _selectedDays = [1, 2, 3, 4, 5, 6, 7];
      _editingDocId = null;
      _editingNotificationId = null;
    });
  }

  Future<void> _deleteMedicine(String docId, int? notificationId) async {
    await FirebaseFirestore.instance
        .collection('medicines')
        .doc(docId)
        .delete();
    // Only cancel local notification if we are the elder (we scheduled it)
    if (notificationId != null && widget.targetElderId == null) {
      for (int i = 1; i <= 7; i++) {
        await NotificationService().cancelNotification(notificationId + i);
      }
      await NotificationService().cancelNotification(notificationId);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Medicine deleted')));
  }

  void _startEdit(Map<String, dynamic> data, String docId) {
    setState(() {
      _editingDocId = docId;
      _nameController.text = data['medicineName'];
      _dosageController.text = data['dosage'];
      _notesController.text = data['notes'] ?? '';
      _editingNotificationId = data['notificationId'];

      if (data['selectedDays'] != null) {
        _selectedDays = List<int>.from(data['selectedDays']);
      } else {
        _selectedDays = [1, 2, 3, 4, 5, 6, 7];
      }

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
      appBar: AppBar(
        title: Text(_editingDocId != null ? 'Edit Medicine' : 'Add Medicine'),
      ),
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
                    decoration: const InputDecoration(
                      labelText: 'Medicine Name',
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _dosageController,
                    decoration: const InputDecoration(
                      labelText: 'Dosage (e.g. 500mg)',
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),

                  // Time Picker Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _selectTime(context),
                      child: Text(
                        _selectedTime == null
                            ? 'Select Time'
                            : 'Time: ${_selectedTime!.format(context)}',
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Select Days:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4.0,
                    children: List.generate(7, (index) {
                      int dayNum = index + 1; // 1 = Monday, 7 = Sunday
                      return FilterChip(
                        label: Text(_weekDays[index], style: const TextStyle(fontSize: 12)),
                        selected: _selectedDays.contains(dayNum),
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _selectedDays.add(dayNum);
                              _selectedDays.sort();
                            } else {
                              if (_selectedDays.length > 1) { // Ensure at least 1 day is selected
                                _selectedDays.remove(dayNum);
                              }
                            }
                          });
                        },
                      );
                    }),
                  ),

                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_editingDocId != null)
                        Expanded(
                          child: TextButton(
                            onPressed: _resetForm,
                            child: const Text("Cancel Edit"),
                          ),
                        ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveMedicine,
                          child: Text(
                            _editingDocId != null
                                ? 'Update Medicine'
                                : 'Save Medicine',
                          ),
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
                    .where('elderId', isEqualTo: widget.targetElderId ?? user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No medicines added yet'));
                  }

                  final docs = snapshot.data!.docs;
                  docs.sort((a, b) {
                    final aTime =
                        (a.data() as Map<String, dynamic>)['createdAt']
                            as Timestamp?;
                    final bTime =
                        (b.data() as Map<String, dynamic>)['createdAt']
                            as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime);
                  });

                  return ListView(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final docId = doc.id;

                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.medication_outlined,
                            color: Colors.teal,
                          ),
                          title: Text(data['medicineName']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${data['dosage']} • ${data['time']}'),
                              Text(
                                _getDaysString(List<int>.from(data['selectedDays'] ?? [1,2,3,4,5,6,7])),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
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

  String _getDaysString(List<int> days) {
    if (days.length == 7) return "Every day";
    List<String> d = days.map((day) => _weekDays[day-1]).toList();
    return d.join(', ');
  }
}
