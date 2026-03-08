import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'auth_wrapper.dart'; // Elder login/auth screen
import 'caregiver_dashboard.dart'; // Caregiver dashboard
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_options_screen.dart';
import 'phone_login_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint("Failed to initialize notifications: $e");
  }

  // Load .env only for non-web
  if (!kIsWeb) {
    await dotenv.load(fileName: ".env");
  }

  // ✅ Platform-safe Firebase initialization
  if (kIsWeb) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  } else {
    await Firebase.initializeApp();
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  try {
    await PushNotificationService().init();
  } catch (e) {
    debugPrint("Failed to initialize push notifications: $e");
  }

  runApp(const ElderlyCareApp());
}

class ElderlyCareApp extends StatelessWidget {
  const ElderlyCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Elderly Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        useMaterial3: true,
      ),
      // Landing page: choose Elder or Caregiver
      home: const RoleSelectionScreen(),
    );
  }
}

// ------------------- Role Selection Screen -------------------
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _selectRole(BuildContext context, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);

    if (role == 'elder') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginOptionsScreen(role: 'Elder'),
        ),
      );
    } else {
      // Caregiver goes directly to login (assuming they just login to manage)
      // Or if you want signup for them too, use LoginOptionsScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PhoneLoginScreen(isLogin: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Role")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Who are you?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            // Elder button
            ElevatedButton.icon(
              icon: const Icon(Icons.person, size: 28),
              label: const Text("Elder", style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.teal,
              ),
              onPressed: () => _selectRole(context, 'elder'),
            ),
            const SizedBox(height: 20),
            // Caregiver button
            ElevatedButton.icon(
              icon: const Icon(Icons.people, size: 28),
              label: const Text("Caregiver", style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.orangeAccent.shade700,
              ),
              onPressed: () => _selectRole(context, 'caregiver'),
            ),
          ],
        ),
      ),
    );
  }
}
