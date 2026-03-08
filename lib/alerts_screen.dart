// alerts_screen.dart

import 'package:flutter/material.dart';

// 1. Data Model for an Alert (Mock data structure)
class SmartAlert {
  final String title;
  final String description;
  final DateTime timestamp;
  final Color color;
  final IconData icon;

  SmartAlert({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.color,
    required this.icon,
  });
}

// 2. Mock Alert Data
final List<SmartAlert> mockAlerts = [
  SmartAlert(
    title: 'Missed Medication (Critical)',
    description: 'The Elder missed their 9:00 AM blood pressure pill.',
    timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
    color: Colors.red.shade700,
    icon: Icons.warning,
  ),
  SmartAlert(
    title: 'Low Battery Warning',
    description: 'The Elder\'s device battery is below 20%.',
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    color: Colors.orange.shade700,
    icon: Icons.battery_alert,
  ),
  SmartAlert(
    title: 'Inactivity Alert',
    description: 'No activity detected for 4 hours (since 1:00 PM).',
    timestamp: DateTime.now().subtract(const Duration(hours: 4, minutes: 15)),
    color: Colors.blue.shade700,
    icon: Icons.personal_injury,
  ),
  SmartAlert(
    title: 'Profile Updated',
    description: 'The Elder successfully updated their weight metric.',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    color: Colors.green.shade700,
    icon: Icons.check_circle,
  ),
];

// 3. The Alerts Screen Widget
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  // Helper to format the time since the alert occurred
  String _timeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort alerts by most recent
    mockAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Alert History'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: mockAlerts.length,
        itemBuilder: (context, index) {
          final alert = mockAlerts[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            elevation: 2,
            child: ListTile(
              leading: Icon(alert.icon, color: alert.color, size: 36),
              title: Text(
                alert.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(alert.description),
              trailing: Text(
                _timeAgo(alert.timestamp),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              onTap: () {
                // Future action: navigate to the related feature (e.g., Medication screen)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Checking details for: ${alert.title}')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}