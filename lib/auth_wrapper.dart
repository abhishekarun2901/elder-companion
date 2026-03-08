import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'caregiver_dashboard.dart';
import 'phone_login_screen.dart'; // The screen for phone number input
// Your main app home screen
import 'profile_check_wrapper.dart'; // Import the new wrapper
import 'main.dart'; // To access RoleSelectionScreen if needed, or just let them fall back

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _userRole;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role');
      _isLoadingRole = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to the authentication state changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the connection is waiting, show a loading indicator.
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isLoadingRole) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If data is present and the user is not null, they are signed in.
        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in. Route based on role.
          if (_userRole == 'caregiver') {
            return const CaregiverDashboard();
          } else {
            // Default to Elder flow if role is elder or null/unknown
            return const ProfileCheckWrapper();
          }
        } else {
          // User is not signed in
          // crucial: If we are here, we might want to guide them back to role selection
          // OR if they just logged out, show the login screen appropriate for their LAST selection?
          // For now, let's just show RoleSelectionScreen if they are fully logged out/initial state
          // BUT, AuthWrapper is usually called AFTER role selection in simple flows.
          // Let's stick to showing the Login Screen if we know the role, or Role Selection if we don't?
          // Actually, if they are not signed in, main.dart shows RoleSelectionScreen as 'home'.
          // This AuthWrapper is only used IF we navigated to it.
          // But wait, main.dart uses RoleSelectionScreen as home.
          // RoleSelectionScreen pushes AuthWrapper (for Elder) or PhoneLogin (for Caregiver).

          // If we are here, it means we navigated to AuthWrapper but user is not logged in.
          // We should show the PhoneLoginScreen (which is what Elder flow expects here).
          return const PhoneLoginScreen();
        }
      },
    );
  }
}
