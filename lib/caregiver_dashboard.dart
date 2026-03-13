// caregiver_dashboard.dart (Multi-Elder Implementation)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'medicine_reminder.dart';
import 'alerts_screen.dart';
import 'health_vitals_screen.dart';
import 'appointment_screen.dart';
import 'chat_summaries_screen.dart';
import 'mood_timeline_screen.dart';
import 'caregiver_adherence_screen.dart';
import 'caregiver_notes_screen.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _showLinkElderDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Link an Elder'),
          content: TextField(
            controller: controller,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Invite Code',
              hintText: 'Enter 6-character code',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = controller.text.trim().toUpperCase();
                if (code.length != 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid 6-character code.')),
                  );
                  return;
                }

                final now = DateTime.now();
                final query = await FirebaseFirestore.instance
                    .collection('users')
                    .where('pendingInviteCode', isEqualTo: code)
                    .limit(10)
                    .get();

                if (query.docs.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid code. Please check with the elder.')),
                    );
                  }
                  return;
                }

                DocumentSnapshot<Map<String, dynamic>>? matched;
                for (final doc in query.docs) {
                  final data = doc.data();
                  final ts = data['inviteCodeExpiresAt'] as Timestamp?;
                  final expiresAt = ts?.toDate();
                  if (expiresAt != null && expiresAt.isAfter(now)) {
                    matched = doc;
                    break;
                  }
                }

                if (matched == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code expired. Ask the elder to generate a new one.')),
                    );
                  }
                  return;
                }

                final data = matched.data() ?? {};
                final elderName = (data['name'] ?? 'the elder').toString();
                final currentPhone = (data['caregiverPhone'] ?? '').toString();
                final myPhone = currentUser?.phoneNumber ?? '';

                if (currentPhone == myPhone && currentPhone.isNotEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Already linked to $elderName.')),
                    );
                  }
                  Navigator.pop(context);
                  return;
                }

                await matched.reference.update({
                  'caregiverPhone': myPhone,
                  'caregiverUid': currentUser?.uid,
                  'pendingInviteCode': null,
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('You are now linked to $elderName.')),
                  );
                }

                Navigator.pop(context);
              },
              child: const Text('Link'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _ensureCaregiverUidLinked(
    String elderId,
    Map<String, dynamic> elderData,
  ) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    final currentLinkedUid = (elderData['caregiverUid'] ?? '').toString();
    if (currentLinkedUid == uid) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(elderId).update({
        'caregiverUid': uid,
      });
    } catch (e) {
      debugPrint('Failed to link caregiverUid for $elderId: $e');
    }
  }

  double? _tryParseDouble(String value) {
    return double.tryParse(value.trim());
  }

  Color _moodColor(String? mood) {
    switch ((mood ?? '').toLowerCase()) {
      case 'happy':
      case 'calm':
        return Colors.green;
      case 'tired':
        return Colors.amber.shade700;
      case 'sad':
      case 'anxious':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

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
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Link an Elder',
            onPressed: _showLinkElderDialog,
          ),
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
                final String lastMood = (elderData['lastMood'] ?? 'Unknown')
                  .toString();

              _ensureCaregiverUidLinked(elderId, elderData);

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
                        const SizedBox(height: 6),
                        Chip(
                          label: Text('Mood: $lastMood'),
                          backgroundColor: _moodColor(lastMood).withOpacity(0.15),
                          side: BorderSide(color: _moodColor(lastMood).withOpacity(0.4)),
                        ),
                        const SizedBox(height: 4),
                        _TodayMedicationStatus(elderId: elderId),
                        const SizedBox(height: 4),
                        _UnreadAlertBadge(
                          elderId: elderId,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AlertsScreen(elderId: elderId),
                              ),
                            );
                          },
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

  Future<void> _showLocateElderOptions(
    BuildContext context,
    String elderId,
    String elderName,
    Map<String, dynamic> elderData,
  ) async {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Open Current Location'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final liveLocation = elderData['liveLocation'] as Map<String, dynamic>?;
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
              ListTile(
                leading: const Icon(Icons.home_work_outlined),
                title: const Text('Set Home Location'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSetHomeLocationDialog(context, elderId, elderData);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSetHomeLocationDialog(
    BuildContext context,
    String elderId,
    Map<String, dynamic> elderData,
  ) async {
    final live = elderData['liveLocation'] as Map<String, dynamic>?;
    final latController = TextEditingController(
      text: (elderData['homeLatitude'] ?? live?['latitude'] ?? '').toString(),
    );
    final lngController = TextEditingController(
      text: (elderData['homeLongitude'] ?? live?['longitude'] ?? '').toString(),
    );
    double sliderRadius =
        ((elderData['geofenceRadiusMeters'] as num?)?.toDouble() ?? 500)
            .clamp(100, 2000);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Set Home Location'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: latController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Latitude'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: lngController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Longitude'),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Radius: ${sliderRadius.round()} m'),
                    ),
                    Slider(
                      min: 100,
                      max: 2000,
                      divisions: 19,
                      value: sliderRadius,
                      label: '${sliderRadius.round()} m',
                      onChanged: (v) {
                        setDialogState(() {
                          sliderRadius = v;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final lat = _tryParseDouble(latController.text);
                    final lng = _tryParseDouble(lngController.text);
                    if (lat == null || lng == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter valid coordinates.')),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(elderId)
                        .set({
                          'homeLatitude': lat,
                          'homeLongitude': lng,
                          'geofenceRadiusMeters': sliderRadius.round(),
                        }, SetOptions(merge: true));

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Home location updated.')),
                      );
                    }

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
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
            await _showLocateElderOptions(context, elderId, elderName, elderData);
          },
        ),
        CaregiverFeatureTile(
          title: 'Alerts',
          subtitle: 'View real-time alerts for $elderName.',
          icon: Icons.notifications_active,
          color: Colors.red,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AlertsScreen(elderId: elderId),
              ),
            );
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
          title: 'Adherence Report',
          subtitle: 'View 7-day medicine adherence for $elderName.',
          icon: Icons.bar_chart,
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CaregiverAdherenceScreen(
                  elderId: elderId,
                  elderName: elderName,
                ),
              ),
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
        CaregiverFeatureTile(
          title: 'Chat Summaries',
          subtitle: 'Review recent AI summaries for $elderName.',
          icon: Icons.summarize,
          color: Colors.indigo,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChatSummariesScreen(elderId: elderId, elderName: elderName),
              ),
            );
          },
        ),
        CaregiverFeatureTile(
          title: 'Mood Timeline',
          subtitle: 'View 7-day mood trends for $elderName.',
          icon: Icons.insights,
          color: Colors.teal,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MoodTimelineScreen(elderId: elderId, elderName: elderName),
              ),
            );
          },
        ),
        CaregiverFeatureTile(
          title: 'Caregiver Notes',
          subtitle: 'Add trusted context for Mitra about $elderName.',
          icon: Icons.note_add,
          color: Colors.brown,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CaregiverNotesScreen(
                  elderId: elderId,
                  elderName: elderName,
                ),
              ),
            );
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

class _UnreadAlertBadge extends StatelessWidget {
  final String elderId;
  final VoidCallback onTap;

  const _UnreadAlertBadge({required this.elderId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(elderId)
          .collection('alerts')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        if (count <= 0) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '$count unread alert${count > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TodayMedicationStatus extends StatelessWidget {
  final String elderId;

  const _TodayMedicationStatus({required this.elderId});

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<Map<String, int>> _compute() async {
    final meds = await FirebaseFirestore.instance
        .collection('medicines')
        .where('elderId', isEqualTo: elderId)
        .get();

    final int weekday = DateTime.now().weekday;
    final String today = _todayKey();

    int scheduled = 0;
    int taken = 0;

    for (final med in meds.docs) {
      final data = med.data();
      final selectedDays = List<int>.from(data['selectedDays'] ?? [1, 2, 3, 4, 5, 6, 7]);
      if (!selectedDays.contains(weekday)) {
        continue;
      }

      scheduled++;
      final log = await med.reference.collection('adherence_logs').doc(today).get();
      if (log.exists) {
        taken++;
      }
    }

    return {'scheduled': scheduled, 'taken': taken};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _compute(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            'Checking medication status…',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          );
        }

        final scheduled = snapshot.data?['scheduled'] ?? 0;
        final taken = snapshot.data?['taken'] ?? 0;

        if (scheduled == 0) {
          return Text(
            'No medicines scheduled for today',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          );
        }

        final pending = scheduled - taken;
        final allTaken = pending <= 0;

        return Text(
          allTaken
              ? 'All meds taken today'
              : '$pending medicine(s) pending today',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: allTaken ? Colors.green.shade700 : Colors.amber.shade900,
          ),
        );
      },
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
