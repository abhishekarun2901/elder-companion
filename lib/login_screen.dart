import 'package:flutter/material.dart';

import 'email_login_screen.dart';
import 'phone_login_screen.dart';
import 'whatsapp_login_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.role,
  });

  final String role;

  @override
  Widget build(BuildContext context) {
    final roleLabel = role[0].toUpperCase() + role.substring(1).toLowerCase();

    return Scaffold(
      appBar: AppBar(title: Text('$roleLabel Login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose an authentication method',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in as $roleLabel using Firebase phone auth, WhatsApp OTP, or email OTP.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 28),
              _MethodButton(
                icon: Icons.phone_android,
                title: 'Login with Phone',
                subtitle: 'Firebase Phone Authentication',
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhoneLoginScreen(role: role),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _MethodButton(
                icon: Icons.chat_bubble_outline,
                title: 'Login with WhatsApp OTP',
                subtitle: 'Backend OTP sent through WhatsApp',
                color: Colors.green.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WhatsappLoginScreen(role: role),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _MethodButton(
                icon: Icons.email_outlined,
                title: 'Login with Email OTP',
                subtitle: 'Receive a one-time code by email',
                color: Colors.orange.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmailLoginScreen(role: role),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.all(18),
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.18),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    );
  }
}
