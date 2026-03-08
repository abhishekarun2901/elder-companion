// lib/health_vitals_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'log_vitals_screen.dart';

// Data model for a vital
class Vital {
  final String title;
  final String unit;
  final String value;
  final String status;
  final Color color;
  final DateTime timestamp;
  final String documentId;

  Vital({
    required this.title,
    required this.unit,
    required this.value,
    required this.status,
    required this.color,
    required this.timestamp,
    required this.documentId,
  });

  // Convert Firestore document to Vital object
  factory Vital.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vital(
      title: data['title'] ?? 'Unknown',
      unit: data['unit'] ?? '',
      value: data['value'] ?? '0',
      status: data['status'] ?? 'Normal',
      color: _getColorForStatus(data['status'] ?? 'Normal'),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      documentId: doc.id,
    );
  }

  static Color _getColorForStatus(String status) {
    switch (status) {
      case 'High':
        return Colors.red;
      case 'Low':
        return Colors.orange;
      case 'Critical':
        return Colors.red.shade900;
      default:
        return Colors.green;
    }
  }
}

// Main vitals screen
class HealthVitalsScreen extends StatefulWidget {
  final String elderName;
  final String? elderId; // ID of the elder (if being viewed by caregiver)

  const HealthVitalsScreen({
    super.key,
    required this.elderName,
    this.elderId,
  });

  @override
  State<HealthVitalsScreen> createState() => _HealthVitalsScreenState();
}

class _HealthVitalsScreenState extends State<HealthVitalsScreen> {
  late Future<List<Vital>> _vitalsFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _vitalsFuture = _fetchLatestVitals();
  }
  
  String get _targetUserId {
    // If elderId is provided, use it. Otherwise use current user's ID.
    return widget.elderId ?? _auth.currentUser?.uid ?? '';
  }

  // Fetch the latest vital for each type from Firestore
  Future<List<Vital>> _fetchLatestVitals() async {
    final uid = _targetUserId;
    if (uid.isEmpty) {
      throw Exception('User not identified');
    }

    final vitalTypes = [
      'Heart Rate',
      'Blood Pressure',
      'Blood Oxygen',
      'Blood Glucose',
      'Steps Count'
    ];

    final List<Future<QuerySnapshot>> futures = [];

    for (var type in vitalTypes) {
      futures.add(
        _firestore
            .collection('users')
            .doc(uid)
            .collection('health_vitals')
            .where('title', isEqualTo: type)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get(),
      );
    }

    final List<QuerySnapshot> results = await Future.wait(futures);
    final List<Vital> vitals = [];

    for (var snapshot in results) {
      if (snapshot.docs.isNotEmpty) {
        vitals.add(Vital.fromFirestore(snapshot.docs.first));
      }
    }

    return vitals;
  }

  // Delete a vital record
  Future<void> _deleteVital(String documentId) async {
    final uid = _targetUserId;
    if (uid.isEmpty) return;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('health_vitals')
          .doc(documentId)
          .delete();

      setState(() {
        _vitalsFuture = _fetchLatestVitals();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vital record deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete vital: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show history of a specific vital type
  void _showVitalHistory(String vitalType) {
    final uid = _targetUserId;
    if (uid.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('History - $vitalType'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<QuerySnapshot>(
              future: _firestore
                  .collection('users')
                  .doc(uid)
                  .collection('health_vitals')
                  .where('title', isEqualTo: vitalType)
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No history available'),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                    final formattedTime = timestamp != null
                        ? '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}'
                        : 'Unknown';

                    return ListTile(
                      title: Text('${data['value']} ${data['unit']}'),
                      subtitle: Text(formattedTime),
                      trailing: Text(
                        data['status'] ?? 'Normal',
                        style: TextStyle(
                          color: Vital._getColorForStatus(data['status'] ?? 'Normal'),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vitals'),
        backgroundColor: Colors.redAccent[700],
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _vitalsFuture = _fetchLatestVitals();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Health Metrics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Vital>>(
              future: _vitalsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No vitals logged yet.\nTap "Manually Log Vitals" to start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                final vitals = snapshot.data!;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10.0,
                    mainAxisSpacing: 10.0,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: vitals.length,
                  itemBuilder: (context, index) {
                    return VitalCard(
                      vital: vitals[index],
                      onDelete: () => _deleteVital(vitals[index].documentId),
                      onViewHistory: () =>
                          _showVitalHistory(vitals[index].title),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'Vitals History & Trends',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Center(
                child: Text(
                  'Charting/Graphing Placeholder\n(Requires Charting Package)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LogVitalsScreen(),
                  ),
                );
                setState(() {
                  _vitalsFuture = _fetchLatestVitals();
                });
              },
              icon: const Icon(Icons.add_circle, color: Colors.white),
              label: const Text(
                'Manually Log Vitals',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Vital card widget with swipe to delete and history view
class VitalCard extends StatelessWidget {
  final Vital vital;
  final VoidCallback onDelete;
  final VoidCallback onViewHistory;

  const VitalCard({
    super.key,
    required this.vital,
    required this.onDelete,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        _showVitalOptions(context);
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: vital.color, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getIconForVital(vital.title),
                    color: vital.color.withOpacity(0.8),
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      vital.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: vital.value,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: vital.color.withOpacity(0.9),
                        ),
                      ),
                      TextSpan(
                        text: ' ${vital.unit}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: vital.color.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: vital.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      vital.status,
                      style: TextStyle(
                        color: vital.color.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    _formatTime(vital.timestamp),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVitalOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.history, color: Colors.blue),
                title: const Text('View History'),
                onTap: () {
                  Navigator.pop(context);
                  onViewHistory();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Record'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Record?'),
          content: Text('Are you sure you want to delete this ${vital.title} record?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onDelete();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final vitalDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (vitalDate == today) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (vitalDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${vitalDate.day}/${vitalDate.month}';
    }
  }

  IconData _getIconForVital(String title) {
    switch (title) {
      case 'Heart Rate':
        return Icons.favorite;
      case 'Blood Pressure':
        return Icons.compress;
      case 'Blood Oxygen':
        return Icons.opacity;
      case 'Blood Glucose':
        return Icons.water_drop;
      case 'Steps Count':
        return Icons.directions_walk;
      default:
        return Icons.health_and_safety;
    }
  }
}