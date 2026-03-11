import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:intl/intl.dart';

import 'profile_details_screen.dart';
import 'chat_screen.dart';
import 'brain_games_screen.dart';
import 'health_vitals_screen.dart';
import 'emergency_contact.dart';
import 'add_medicine_screen.dart';
import 'medicine_reminder.dart';  // Import the overhauled screen
import 'services/voice_service.dart';
import 'services/notification_service.dart';
import 'sudoku.dart';
import 'memory_game.dart'; // Import MemoryGame
import 'appointment_screen.dart'; // Import AppointmentScreen
import 'services/location_service.dart'; // Import LocationService

// --- Data Model for Features ---
class CareFeature {
  final String title;
  final IconData icon;
  final Color color;
  final Function(BuildContext) onTap;

  CareFeature({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

// --- Home Screen Widget ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _emergencyContactName;
  String? _emergencyContactPhone;
  String? _userName;
  final VoiceService _voiceService = VoiceService();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContact();
    _updateLiveLocation();
    _voiceService.isListeningNotifier.addListener(_onListeningStateChanged);
    NotificationService().init(); // Initialize Notifications
  }

  @override
  void dispose() {
    _voiceService.isListeningNotifier.removeListener(_onListeningStateChanged);
    super.dispose();
  }

  void _onListeningStateChanged() {
    // Safely update state if widget is still mounted
    if (mounted) {
      setState(() {
        _isListening = _voiceService.isListening;
      });
    }
  }

  // Load emergency contact from Firebase
  Future<void> _loadEmergencyContact() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!docSnapshot.exists) return;

    final data = docSnapshot.data();
    setState(() {
      _userName = data?['name'];
      _emergencyContactName = data?['emergencyContact']?['name'];
      _emergencyContactPhone = data?['emergencyContact']?['phone'];
    });
  }

  // Update Live Location to Firestore
  Future<void> _updateLiveLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final locationService = LocationService();
    final position = await locationService.getCurrentLocation();

    if (position != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'liveLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    }
  }

  // Emergency SMS Alert
  Future<void> _sendSMSAlert() async {
    if (_emergencyContactPhone == null || _emergencyContactPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No emergency contact found. Please update your profile.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send Emergency Alert?'),
        content: Text(
          'This will send an SMS to $_emergencyContactName ($_emergencyContactPhone).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      
      // Update Emergency State
      await userDoc.set({
        'emergencyState': {
          'isActive': true,
          'timestamp': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      // Record in History
      await userDoc.collection('sos_history').add({
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Triggered',
        'triggeredBy': _userName ?? 'Elder',
      });
    }

    final message = Uri.encodeComponent(
      'EMERGENCY ALERT: ${_userName ?? "Your elder"} needs immediate assistance.',
    );

    final smsUri = Uri(
      scheme: 'sms',
      path: _emergencyContactPhone,
      queryParameters: {'body': message},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  // Voice Command Listener
  void _toggleListening() {
    if (_isListening) {
      _voiceService.stopListening();
    } else {
      _voiceService.startListening(
        onResult: (text) {
          _processVoiceCommand(text);
        },
      );
    }
  }

  void _processVoiceCommand(String command) {
    debugPrint("Voice Command: $command");
    final lowerCommand = command.toLowerCase();

    if (lowerCommand.contains("sudoku") || lowerCommand.contains("game")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SudokuGameScreen()),
      );
    } else if (lowerCommand.contains("memory") ||
        lowerCommand.contains("card")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MemoryGameScreen()),
      );
    } else if (lowerCommand.contains("chat") || lowerCommand.contains("talk")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatPage(title: 'Chat')),
      );
    } else if (lowerCommand.contains("medicine") ||
        lowerCommand.contains("pill")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
      );
    } else if (lowerCommand.contains("emergency") ||
        lowerCommand.contains("help")) {
      _sendSMSAlert();
    } else if (lowerCommand.contains("health") ||
        lowerCommand.contains("vitals")) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HealthVitalsScreen(elderName: "John"),
        ),
      );
    } else if (lowerCommand.contains("contact") ||
        lowerCommand.contains("call")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EmergencyContactScreen()),
      );
    } else if (lowerCommand.contains("event") ||
        lowerCommand.contains("doctor") || lowerCommand.contains("appointment")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AppointmentScreen()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Did not understand: $command")));
    }
  }

  // 🔁 CENTRAL FEATURE HANDLER
  void handleFeatureTap(BuildContext context, String featureTitle) {
    switch (featureTitle) {
      case 'Chatbot':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatPage(title: 'Chat')),
        );
        break;

      case 'Events':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentScreen()),
        );
        break;

      case 'My Medicines':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MedicineReminder()),
        );
        break;

      case 'Locate Nearby':
        _showComingSoon(featureTitle);
        break;

      case 'Contact Relatives':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyContactScreen()),
        );
        break;

      case 'Emergency':
        _sendSMSAlert();
        break;

      case 'Health Tracker':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HealthVitalsScreen(elderName: "John"),
          ),
        );
        break;

      case 'Brain Games':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BrainGamesScreen()),
        );
        break;

      default:
        break;
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature coming soon')));
  }

  // --- Feature List ---
  List<CareFeature> get _features => [
    CareFeature(
      title: 'Chatbot',
      icon: Icons.chat_bubble_outline,
      color: Colors.green.shade600,
      onTap: (c) => handleFeatureTap(c, 'Chatbot'),
    ),

    CareFeature(
      title: 'Events',
      icon: Icons.event,
      color: Colors.deepPurple,
      onTap: (c) => handleFeatureTap(c, 'Events'),
    ),

    CareFeature(
      title: 'My Medicines',
      icon: Icons.medical_services,
      color: Colors.orange,
      onTap: (c) => handleFeatureTap(c, 'My Medicines'),
    ),

    CareFeature(
      title: 'Locate Nearby',
      icon: Icons.local_hospital,
      color: Colors.teal.shade800,
      onTap: (c) => handleFeatureTap(c, 'Locate Nearby'),
    ),

    CareFeature(
      title: 'Contact Relatives',
      icon: Icons.accessibility_new,
      color: Colors.pink.shade700,
      onTap: (c) => handleFeatureTap(c, 'Contact Relatives'),
    ),

    CareFeature(
      title: 'Emergency',
      icon: Icons.warning,
      color: Colors.red.shade700,
      onTap: (c) => handleFeatureTap(c, 'Emergency'),
    ),

    CareFeature(
      title: 'Brain Games',
      icon: Icons.psychology,
      color: Colors.purple.shade600,
      onTap: (c) => handleFeatureTap(c, 'Brain Games'),
    ),

    CareFeature(
      title: 'Health Tracker',
      icon: Icons.monitor_heart,
      color: Colors.blue.shade700,
      onTap: (c) => handleFeatureTap(c, 'Health Tracker'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elderly Companion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileDetailsScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDailyMedsBanner(),
            _buildAppointmentsBanner(),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: _features.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.7,
                ),
                itemBuilder: (context, index) =>
                    CareFeatureButton(feature: _features[index]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleListening,
        backgroundColor: _isListening ? Colors.red : Colors.teal,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- Daily Medications Banner ---
  Widget _buildDailyMedsBanner() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medicines')
          .where('elderId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); 
        }

        final allDocs = snapshot.data!.docs;
        final int currentWeekday = DateTime.now().weekday;
        
        final docs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final days = List<int>.from(data['selectedDays'] ?? [1,2,3,4,5,6,7]);
          return days.contains(currentWeekday);
        }).toList();

        if (docs.isEmpty) {
          return const SizedBox.shrink(); // Hide if completely empty schedule for today
        }
        
        // We will build a list of Un-taken medications
        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(docs.map((medDoc) async {
            final logDoc = await FirebaseFirestore.instance
                .collection('medicines')
                .doc(medDoc.id)
                .collection('adherence_logs')
                .doc(todayKey)
                .get();
            // Return null if taken, return medDoc if NOT taken
            return logDoc.exists ? null : medDoc;
          }).toList()).then((list) => list.where((doc) => doc != null).cast<DocumentSnapshot>().toList()), // filter out nulls
          builder: (context, pendingSnapshot) {
            if (pendingSnapshot.hasError) {
              return Text("Error loading adherence: ${pendingSnapshot.error}", style: const TextStyle(color: Colors.red));
            }

            // Need to handle state while Futures are resolving
            if (pendingSnapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            final pendingMeds = pendingSnapshot.data ?? [];
            if (pendingMeds.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text("You've taken all your medicines today! 🎉", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Action Needed", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                        Text("You have ${pendingMeds.length} pending medication${pendingMeds.length == 1 ? '' : 's'} today.", style: TextStyle(color: Colors.orange.shade900)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MedicineReminder()),
                      );
                      // Force rebuild when returning
                      if (mounted) setState(() {});
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    child: const Text("View"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Upcoming Appointments Banner ---
  Widget _buildAppointmentsBanner() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final now = DateTime.now();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('elderId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final allDocs = snapshot.data!.docs;

        // Filter for ONLY appointments scheduled for TODAY
        final todaysAppointments = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dt = DateTime.parse(data['dateTime']);
          return dt.year == now.year && dt.month == now.month && dt.day == now.day;
        }).toList();

        if (todaysAppointments.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.deepPurple, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Upcoming Event", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple)),
                    Text("You have ${todaysAppointments.length} event${todaysAppointments.length == 1 ? '' : 's'} today.", style: TextStyle(color: Colors.deepPurple.shade900)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AppointmentScreen()),
                  );
                  if (mounted) setState(() {});
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                child: const Text("View"),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- Feature Button ---
class CareFeatureButton extends StatelessWidget {
  final CareFeature feature;
  const CareFeatureButton({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => feature.onTap(context),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: feature.color,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(feature.icon, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 8),
          Text(
            feature.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
