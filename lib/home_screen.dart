import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'profile_details_screen.dart';
import 'chat_screen.dart';
import 'brain_games_screen.dart';
import 'health_vitals_screen.dart';
import 'emergency_contact.dart';
import 'add_medicine_screen.dart';
import 'services/voice_service.dart'; // Import VoiceService
import 'services/notification_service.dart'; // Import NotificationService
import 'sudoku.dart'; // Import Sudoku
import 'memory_game.dart'; // Import MemoryGame
import 'appointment_screen.dart'; // Import AppointmentScreen

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

    final docSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!docSnapshot.exists) return;

    final data = docSnapshot.data();
    setState(() {
      _userName = data?['name'];
      _emergencyContactName = data?['emergencyContact']?['name'];
      _emergencyContactPhone = data?['emergencyContact']?['phone'];
    });
  }

  // Emergency SMS Alert
  Future<void> _sendSMSAlert() async {
    if (_emergencyContactPhone == null || _emergencyContactPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No emergency contact found. Please update your profile.'),
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
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Send Alert')),
        ],
      ),
    );

    if (confirmed != true) return;

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
    } else if (lowerCommand.contains("memory") || lowerCommand.contains("card")) {
       Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MemoryGameScreen()),
      );
    } else if (lowerCommand.contains("chat") || lowerCommand.contains("talk")) {
      Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatPage(title: 'Chat')),
      );
    } else if (lowerCommand.contains("medicine") || lowerCommand.contains("pill")) {
      Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
      );
    } else if (lowerCommand.contains("emergency") || lowerCommand.contains("help")) {
      _sendSMSAlert();
    } else if (lowerCommand.contains("health") || lowerCommand.contains("vitals")) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HealthVitalsScreen(elderName: "John"),
        ),
      );
    } else if (lowerCommand.contains("contact") || lowerCommand.contains("call")) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const EmergencyContactScreen()),
      );
    } else if (lowerCommand.contains("appointment") || lowerCommand.contains("doctor")) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentScreen()),
        );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Did not understand: $command")),
      );
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

      case 'Appointment':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentScreen()),
        );
        break;

      case 'Add Medicine':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
        );
        break;

      case 'Locate Nearby':
        _showComingSoon(featureTitle);
        break;

      case 'Contact Relatives':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const EmergencyContactScreen()),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon')),
    );
  }

  // --- Feature List ---
  List<CareFeature> get _features => [
        CareFeature(
            title: 'Chatbot',
            icon: Icons.chat_bubble_outline,
            color: Colors.green.shade600,
            onTap: (c) => handleFeatureTap(c, 'Chatbot')),

        CareFeature(
            title: 'Appointment',
            icon: Icons.person_pin_circle,
            color: Colors.deepPurple,
            onTap: (c) => handleFeatureTap(c, 'Appointment')),

        CareFeature(
            title: 'Add Medicine',
            icon: Icons.medical_services,
            color: Colors.orange,
            onTap: (c) => handleFeatureTap(c, 'Add Medicine')),

        CareFeature(
            title: 'Locate Nearby',
            icon: Icons.local_hospital,
            color: Colors.teal.shade800,
            onTap: (c) => handleFeatureTap(c, 'Locate Nearby')),

        CareFeature(
            title: 'Contact Relatives',
            icon: Icons.accessibility_new,
            color: Colors.pink.shade700,
            onTap: (c) => handleFeatureTap(c, 'Contact Relatives')),

        CareFeature(
            title: 'Emergency',
            icon: Icons.warning,
            color: Colors.red.shade700,
            onTap: (c) => handleFeatureTap(c, 'Emergency')),

        CareFeature(
            title: 'Brain Games',
            icon: Icons.psychology,
            color: Colors.purple.shade600,
            onTap: (c) => handleFeatureTap(c, 'Brain Games')),

        CareFeature(
            title: 'Health Tracker',
            icon: Icons.monitor_heart,
            color: Colors.blue.shade700,
            onTap: (c) => handleFeatureTap(c, 'Health Tracker')),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleListening,
        backgroundColor: _isListening ? Colors.red : Colors.teal,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
