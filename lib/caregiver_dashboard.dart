// caregiver_dashboard.dart (Multi-Elder Implementation)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'medicine_reminder.dart';
import 'alerts_screen.dart';
import 'health_vitals_screen.dart';
import 'appointment_screen.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Caregiver Tools',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.blueGrey.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('caregiverPhone', isEqualTo: currentUser!.phoneNumber)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "No Elders found linked to your number (${currentUser!.phoneNumber}).\n\nPlease ensure the Elder has entered your phone number correctly in their profile.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            );
          }

          final elders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: elders.length,
            itemBuilder: (context, index) {
              final elderData = elders[index].data() as Map<String, dynamic>;
              final String elderName = elderData['name'] ?? 'Unknown Elder';
              final String elderId = elders[index].id;

               final bool isEmergencyActive = elderData['emergencyState']?['isActive'] == true;

               return Card(
                 color: isEmergencyActive ? Colors.red.shade50 : Colors.teal.shade50,
                 margin: const EdgeInsets.only(bottom: 20),
                 child: Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        if (isEmergencyActive) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "ACTIVE EMERGENCY",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _resolveEmergency(elderId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Resolve'),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          "Managing: $elderName",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                        ),
                        const Divider(),
                        _buildElderActions(context, elderName, elderId, elderData),
                     ],
                   ),
                 ),
               );
            },
          );
        },
      ),
    );
  }

  Future<void> _resolveEmergency(String elderId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(elderId).set({
        'emergencyState': {
          'isActive': false,
        }
      }, SetOptions(merge: true));
      
      await FirebaseFirestore.instance.collection('users').doc(elderId).collection('sos_history').add({
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Resolved by Caregiver',
        'resolvedBy': currentUser?.phoneNumber,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency resolved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve emergency: $e')),
        );
      }
    }
  }

  Widget _buildElderActions(
    BuildContext context,
    String elderName,
    String elderId,
    Map<String, dynamic> elderData,
  ) {
    return Column(
      children: [
        CaregiverFeatureTile(
          title: 'Health Vitals Status',
          subtitle: 'View latest vitals for $elderName.',
          icon: Icons.monitor_heart,
          color: Colors.redAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    HealthVitalsScreen(elderName: elderName, elderId: elderId),
              ),
            );
          },
        ),
        CaregiverFeatureTile(
          title: 'Locate Elder',
          subtitle: 'Check current location of $elderName.',
          icon: Icons.location_on,
          color: Colors.green,
          onTap: () async {
            final liveLocation =
                elderData['liveLocation'] as Map<String, dynamic>?;
            if (liveLocation != null &&
                liveLocation['latitude'] != null &&
                liveLocation['longitude'] != null) {
              final lat = liveLocation['latitude'];
              final lng = liveLocation['longitude'];
              final url = Uri.parse('https://maps.google.com/?q=$lat,$lng');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open map.')),
                  );
                }
              }
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Location not available yet for $elderName.'),
                  ),
                );
              }
            }
          },
        ),
        CaregiverFeatureTile(
          title: 'Manage Medications',
          subtitle: 'Check reminders for $elderName.',
          icon: Icons.edit_calendar,
          color: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MedicineReminder(targetElderId: elderId)),
            );
          },
        ),
        CaregiverFeatureTile(
            title: 'Manage Events',
            subtitle: 'Add or remove events/appointments for $elderName.',
            icon: Icons.event,
            color: Colors.deepPurple,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentScreen(targetElderId: elderId)));
            },
        ),
        CaregiverFeatureTile(
            title: 'SOS History',
            subtitle: 'View past emergency alerts.',
            icon: Icons.history,
            color: Colors.blueGrey,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => SosHistoryScreen(elderId: elderId)));
            },
          ),
      ],
    );
  }
}

class CaregiverFeatureTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CaregiverFeatureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}

class SosHistoryScreen extends StatelessWidget {
  final String elderId;

  const SosHistoryScreen({required this.elderId, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS History'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(elderId)
            .collection('sos_history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No SOS history found.', style: TextStyle(fontSize: 16, color: Colors.grey)));
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index].data() as Map<String, dynamic>;
              final timestamp = log['timestamp'] as Timestamp?;
              final dateStr = timestamp != null 
                  ? "${timestamp.toDate().toLocal().toString().split('.')[0]}" 
                  : "Unknown Time";
              final status = log['status'] ?? 'Unknown';

              return ListTile(
                leading: Icon(
                  status.toString().contains('Resolved') ? Icons.check_circle : Icons.warning,
                  color: status.toString().contains('Resolved') ? Colors.green : Colors.red,
                ),
                title: Text(status),
                subtitle: Text(dateStr),
              );
            },
          );
        },
      ),
    );
  }
}
