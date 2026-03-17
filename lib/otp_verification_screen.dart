import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'auth_service.dart';
import 'auth_wrapper.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.initialSession,
    required this.onVerify,
    required this.onResend,
  });

  final String title;
  final String subtitle;
  final AuthOtpSession initialSession;
  final Future<void> Function(AuthOtpSession session, String otp) onVerify;
  final Future<AuthOtpSession> Function(AuthOtpSession session) onResend;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  late AuthOtpSession _session;

  Timer? _timer;
  late int _secondsRemaining;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    _secondsRemaining = _session.expiresInSeconds;
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
        return;
      }

      setState(() => _secondsRemaining -= 1);
    });
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    setState(() => _isVerifying = true);

    try {
      await widget.onVerify(_session, _otpController.text);
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } on AuthFlowException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('Unable to verify OTP right now.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resend() async {
    FocusScope.of(context).unfocus();
    setState(() => _isResending = true);

    try {
      final updatedSession = await widget.onResend(_session);
      if (!mounted) return;

      setState(() {
        _session = updatedSession;
        _secondsRemaining = updatedSession.expiresInSeconds;
        _otpController.clear();
      });
      _startCountdown();

      _showMessage('A fresh OTP has been sent.');
    } on AuthFlowException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('Unable to resend OTP right now.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.teal,
      ),
    );
  }

  String get _timeLabel {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Destination: ${_session.destinationHint}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            PinCodeTextField(
              appContext: context,
              controller: _otpController,
              length: 6,
              keyboardType: TextInputType.number,
              autoDisposeControllers: false,
              enableActiveFill: true,
              animationType: AnimationType.fade,
              pastedTextStyle: const TextStyle(fontWeight: FontWeight.w600),
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(12),
                fieldHeight: 56,
                fieldWidth: 46,
                activeFillColor: Colors.teal.shade50,
                selectedFillColor: Colors.teal.shade100,
                inactiveFillColor: Colors.grey.shade100,
                activeColor: Colors.teal,
                selectedColor: Colors.teal.shade700,
                inactiveColor: Colors.grey.shade400,
              ),
              animationDuration: const Duration(milliseconds: 180),
              onChanged: (_) {},
              beforeTextPaste: (_) => true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  _secondsRemaining > 0
                      ? 'Expires in $_timeLabel'
                      : 'OTP expired. Resend to continue.',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isVerifying ? null : _verify,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isVerifying
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verify OTP'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isResending ? null : _resend,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isResending
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Resend OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
