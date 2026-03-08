// In your otp_screen.dart
import 'auth_wrapper.dart'; // Correct import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// Import your Home Screen

class OTPScreen extends StatefulWidget {
  final String verificationId; // Receive verificationId from the previous screen

  const OTPScreen({super.key, required this.verificationId});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    final String smsCode = _otpController.text.trim();
    if (smsCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create a PhoneAuthCredential with the code
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: smsCode,
      );

      // Sign the user in with the credential
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // If sign-in is successful, navigate to the home screen
      if (userCredential.user != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()), // Correctly route via AuthWrapper
              (Route<dynamic> route) => false,// This removes all previous routes
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to verify OTP: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter OTP')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '6-Digit OTP'),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _verifyOtp,
              child: const Text('Verify OTP'),
            ),
          ],
        ),
      ),
    );
  }
}