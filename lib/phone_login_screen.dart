import 'package:firebase_auth/firebase_auth.dart';
// Import this for kIsWeb
import 'package:flutter/material.dart';
// Import your OTP screen
import 'otp_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  final bool isLogin; // true = login, false = signup
  const PhoneLoginScreen({super.key, this.isLogin = true});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    final String phoneNumber = '+91${_phoneController.text.trim()}';
    if (phoneNumber.length != 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // For web, the reCAPTCHA is handled automatically by verifyPhoneNumber.
    // We no longer need to manually create or pass a RecaptchaVerifier instance
    // for the standard popup flow.
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // This is mainly for Android auto-retrieval
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading = false;
        });
        print("---------------------------------------------");
        print("FIREBASE AUTHENTICATION FAILED");
        print("Error Code: ${e.code}");
        print("Error Message: ${e.message}");
        print("---------------------------------------------");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _isLoading = false;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(verificationId: verificationId),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // You can handle this if needed
      },
      timeout: const Duration(seconds: 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Phone Number')),
      // The Stack and manual RecaptchaVerifier are no longer needed.
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  onPressed: _sendOtp,
                  child: const Text('Send OTP'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

