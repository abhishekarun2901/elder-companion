// medicine_reminder.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MedicineReminder extends StatefulWidget {
  const MedicineReminder({super.key});

  @override
  State<MedicineReminder> createState() => _MedicineReminderState();
}

class _MedicineReminderState extends State<MedicineReminder> {
  // Sample list of medicines with time
  final List<Medicine> _medicines = [
    Medicine(name: "Vitamin D", time: TimeOfDay(hour: 8, minute: 0)),
    Medicine(name: "Blood Pressure Pill", time: TimeOfDay(hour: 12, minute: 0)),
    Medicine(name: "Heart Medicine", time: TimeOfDay(hour: 20, minute: 30)),
  ];

  // Track if medicine has been taken
  final Map<String, bool> _taken = {};

  @override
  void initState() {
    super.initState();
    for (var med in _medicines) {
      _taken[med.name] = false; // initially not taken
    }
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  void _toggleTaken(String medName) {
    setState(() {
      _taken[medName] = !(_taken[medName] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Medicine Reminders"),
        backgroundColor: Colors.teal,
      ),
      body: ListView.builder(
        itemCount: _medicines.length,
        itemBuilder: (context, index) {
          final med = _medicines[index];
          final isTaken = _taken[med.name] ?? false;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isTaken ? Colors.green : Colors.redAccent, width: 2),
            ),
            child: ListTile(
              leading: Icon(
                isTaken ? Icons.check_circle : Icons.medical_services,
                color: isTaken ? Colors.green : Colors.redAccent,
                size: 30,
              ),
              title: Text(
                med.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  decoration: isTaken ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text("Time: ${_formatTime(med.time)}"),
              trailing: IconButton(
                icon: Icon(
                  isTaken ? Icons.undo : Icons.check,
                  color: isTaken ? Colors.orange : Colors.green,
                ),
                onPressed: () => _toggleTaken(med.name),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Model for medicine
class Medicine {
  final String name;
  final TimeOfDay time;

  Medicine({required this.name, required this.time});
}
