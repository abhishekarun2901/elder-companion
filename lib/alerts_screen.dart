// alerts_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AlertsScreen extends StatelessWidget {
  final String elderId;

  const AlertsScreen({super.key, required this.elderId});

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

  IconData _iconForType(String type) {
    switch (type) {
      case 'distress':
        return Icons.warning_amber_rounded;
      case 'medication_miss':
        return Icons.medication;
      case 'sos':
        return Icons.emergency;
      case 'inactivity':
        return Icons.personal_injury;
      case 'geofence':
        return Icons.location_off;
      default:
        return Icons.notifications_active;
    }
  }

  Color _colorForSeverity(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return Colors.red.shade700;
      case 'WARNING':
        return Colors.orange.shade700;
      case 'INFO':
        return Colors.blue.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  String _defaultTitleForType(String type) {
    switch (type) {
      case 'distress':
        return 'Distress Alert';
      case 'medication_miss':
        return 'Medication Missed';
      case 'sos':
        return 'SOS Triggered';
      case 'inactivity':
        return 'Inactivity Alert';
      case 'geofence':
        return 'Geofence Alert';
      default:
        return 'Alert';
    }
  }

  Future<void> _markAllRead() async {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(elderId)
        .collection('alerts');
    final unread = await col.where('isRead', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Alert History'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () async {
              await _markAllRead();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All alerts marked as read.')),
                );
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(elderId)
            .collection('alerts')
            .orderBy('createdAt', descending: true)
          .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No alerts yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final type = (data['type'] ?? '').toString();
              final severity = (data['severity'] ?? 'INFO').toString();
              final title =
                  (data['title'] ?? _defaultTitleForType(type)).toString();
              final description = (data['description'] ??
                      data['messageSnippet'] ??
                      'Alert detected.')
                  .toString();
              final createdAt = data['createdAt'] as Timestamp?;
              final isRead = data['isRead'] == true;

              final icon = _iconForType(type);
              final color = _colorForSeverity(severity);
              final when = createdAt?.toDate();

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                elevation: isRead ? 1 : 3,
                child: ListTile(
                  leading: Icon(icon, color: color, size: 32),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(description),
                  trailing: Text(
                    when == null ? '--' : _timeAgo(when),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  onTap: () async {
                    await doc.reference.update({'isRead': true});
                    if (!context.mounted) return;
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(description),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
