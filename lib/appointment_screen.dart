import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/notification_service.dart';

class AppointmentScreen extends StatefulWidget {
  final String? targetElderId;

  const AppointmentScreen({super.key, this.targetElderId});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _doctorController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _doctorController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }
    final currentUserId = user?.uid;
    final elderIdToUse = widget.targetElderId ?? currentUserId;

    if (elderIdToUse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot identify Elder ID!')),
      );
      return;
    }

    final DateTime scheduledDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    if (scheduledDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot schedule in the past')),
      );
      return;
    }

    // Generate a unique ID for notification
    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // ensure int32
    notificationId = notificationId & 0x7FFFFFFF;

    try {
      await FirebaseFirestore.instance.collection('appointments').add({
        'elderId': elderIdToUse,
        'doctorName': _doctorController.text.trim(),
        'location': _locationController.text.trim(),
        'dateTime': scheduledDateTime.toIso8601String(),
        'notes': _notesController.text.trim(),
        'notificationId': notificationId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Schedule LOCAL Notification ONLY if the current user is the elder themselves.
      // Remote Caregiver push notifications will be handled by the Firebase Cloud Function.
      if (widget.targetElderId == null) {
        await NotificationService().scheduleNotification(
          id: notificationId,
          title: "Appointment Reminder",
          body:
              "You have an appointment with ${_doctorController.text} at ${_locationController.text}",
          scheduledTime: scheduledDateTime,
        );
      }

      _doctorController.clear();
      _locationController.clear();
      _notesController.clear();
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event scheduled')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scheduling event: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events & Appointments')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------- ADD APPOINTMENT FORM ----------
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _doctorController,
                    decoration: const InputDecoration(labelText: 'Person / Event Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _selectDate(context),
                          child: Text(
                            _selectedDate == null
                                ? 'Select Date'
                                : DateFormat.yMMMd().format(_selectedDate!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _selectTime(context),
                          child: Text(
                            _selectedTime == null
                                ? 'Select Time'
                                : _selectedTime!.format(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveAppointment,
                      child: const Text('Schedule Event'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---------- APPOINTMENT LIST ----------
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Upcoming Events",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('appointments')
                    .where('elderId', isEqualTo: widget.targetElderId ?? user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No events scheduled'),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  docs.sort((a, b) {
                    final aDate = DateTime.parse(
                      (a.data() as Map<String, dynamic>)['dateTime'],
                    );
                    final bDate = DateTime.parse(
                      (b.data() as Map<String, dynamic>)['dateTime'],
                    );
                    return aDate.compareTo(bDate);
                  });

                  return ListView(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final DateTime dt = DateTime.parse(data['dateTime']);

                      // Check if appointment is in the past
                      if (dt.isBefore(DateTime.now())) {
                        // Optionally hide or style differently
                      }

                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.event,
                            color: Colors.deepPurple,
                          ),
                          title: Text(data['doctorName'] ?? 'Event'),
                          subtitle: Text(
                            '${DateFormat.yMMMd().format(dt)} at ${DateFormat.jm().format(dt)}\n${data['location'] ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteAppointment(doc.id, data['notificationId']),
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

  Future<void> _deleteAppointment(String docId, dynamic notificationId) async {
    try {
      await FirebaseFirestore.instance.collection('appointments').doc(docId).delete();
      
      // Attempt to cancel local notification if it exists and we're the elder
      if (widget.targetElderId == null && notificationId != null) {
          NotificationService().cancelNotification(notificationId as int);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete event: $e')),
        );
      }
    }
  }
}
