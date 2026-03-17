import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'otp_verification_screen.dart';

class WhatsappLoginScreen extends StatefulWidget {
  const WhatsappLoginScreen({
    super.key,
    this.role = 'elder',
  });

  final String role;

  @override
  State<WhatsappLoginScreen> createState() => _WhatsappLoginScreenState();
}

class _WhatsappLoginScreenState extends State<WhatsappLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final session = await AuthService.instance.startBackendOtp(
        channel: AuthChannel.whatsapp,
        identifier: _phoneController.text,
      );
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            title: 'Check WhatsApp',
            subtitle:
                'We sent a one-time password to your WhatsApp number. Enter it below to continue.',
            initialSession: session,
            onVerify: AuthService.instance.verifyBackendOtp,
            onResend: AuthService.instance.resendBackendOtp,
          ),
        ),
      );
    } on AuthFlowException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('Unable to send the WhatsApp OTP.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp OTP Login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WhatsApp OTP Authentication',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your backend will generate and verify the OTP, then hand Firebase a custom token session.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp OTP delivery',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text('Send OTPs to any valid WhatsApp-enabled phone number.'),
                    SizedBox(height: 4),
                    Text('This requires your backend WhatsApp Cloud API credentials or a configured demo login.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Number',
                  hintText: '+919207037558',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send WhatsApp OTP'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
