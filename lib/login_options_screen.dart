import 'package:flutter/material.dart';
import 'phone_login_screen.dart';

class LoginOptionsScreen extends StatelessWidget {
  final String role; // 'elder' or 'caregiver'

  const LoginOptionsScreen({super.key, required this.role});

  void _navigateToLogin(BuildContext context, bool isSignup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhoneLoginScreen(
          isLogin: isSignup == false,
        ), // isSignup is true for create account
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$role Login Options".toUpperCase())),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Welcome, $role!",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.teal,
              ),
              onPressed: () => _navigateToLogin(context, false), // Login
              child: const Text(
                "Login (Existing Account)",
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                side: const BorderSide(color: Colors.teal, width: 2),
              ),
              onPressed: () => _navigateToLogin(context, true), // Signup
              child: const Text(
                "Create New Account",
                style: TextStyle(fontSize: 20, color: Colors.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
