import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum AuthChannel {
  phone,
  whatsapp,
  email,
}

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthOtpSession {
  const AuthOtpSession({
    required this.channel,
    required this.identifier,
    required this.destinationHint,
    this.verificationId,
    this.resendToken,
    this.expiresInSeconds = 300,
    this.devOtpHint,
  });

  final AuthChannel channel;
  final String identifier;
  final String destinationHint;
  final String? verificationId;
  final int? resendToken;
  final int expiresInSeconds;
  final String? devOtpHint;

  AuthOtpSession copyWith({
    AuthChannel? channel,
    String? identifier,
    String? destinationHint,
    String? verificationId,
    int? resendToken,
    int? expiresInSeconds,
    String? devOtpHint,
  }) {
    return AuthOtpSession(
      channel: channel ?? this.channel,
      identifier: identifier ?? this.identifier,
      destinationHint: destinationHint ?? this.destinationHint,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      expiresInSeconds: expiresInSeconds ?? this.expiresInSeconds,
      devOtpHint: devOtpHint ?? this.devOtpHint,
    );
  }
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const String _defaultRegion = 'us-central1';
  static const String _lastLoginMethodKey = 'last_login_method';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  ConfirmationResult? _webConfirmationResult;

  String get apiBaseUrl {
    final configuredUrl = dotenv.env['AUTH_API_BASE_URL'];
    if (configuredUrl != null && configuredUrl.trim().isNotEmpty) {
      return configuredUrl.trim().replaceAll(RegExp(r'/$'), '');
    }

    final configuredRegion = dotenv.env['AUTH_API_REGION'];
    final region = configuredRegion != null && configuredRegion.trim().isNotEmpty
        ? configuredRegion.trim()
        : _defaultRegion;
    final projectId = Firebase.app().options.projectId;
    return 'https://$region-$projectId.cloudfunctions.net/authApi';
  }

  String normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) {
      return '+$digits';
    }
    if (digits.length == 10) {
      return '+91$digits';
    }
    if (value.trim().startsWith('+') && digits.length >= 10) {
      return '+$digits';
    }
    throw const AuthFlowException(
      'Enter a valid phone number, for example +919207027558.',
    );
  }

  String normalizeEmail(String value) {
    final email = value.trim().toLowerCase();
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      throw const AuthFlowException('Enter a valid email address.');
    }
    return email;
  }

  Future<void> persistLastLoginMethod(AuthChannel channel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastLoginMethodKey, channel.name);
  }

  Future<AuthOtpSession> startPhoneLogin(String rawPhone) async {
    final phoneNumber = normalizePhone(rawPhone);
    final verificationData = kIsWeb
        ? await _requestPhoneVerificationWeb(phoneNumber)
        : await _requestPhoneVerification(phoneNumber);
    return AuthOtpSession(
      channel: AuthChannel.phone,
      identifier: phoneNumber,
      destinationHint: phoneNumber,
      verificationId: verificationData.verificationId,
      resendToken: verificationData.resendToken,
      expiresInSeconds: 300,
    );
  }

  Future<AuthOtpSession> resendPhoneOtp(AuthOtpSession session) async {
    final verificationData = kIsWeb
        ? await _requestPhoneVerificationWeb(session.identifier)
        : await _requestPhoneVerification(
            session.identifier,
            resendToken: session.resendToken,
          );
    return session.copyWith(
      verificationId: verificationData.verificationId,
      resendToken: verificationData.resendToken,
      expiresInSeconds: 300,
    );
  }

  Future<void> verifyPhoneOtp(AuthOtpSession session, String otp) async {
    final code = _normalizeOtp(otp);

    if (kIsWeb) {
      final confirmationResult = _webConfirmationResult;
      if (confirmationResult == null) {
        throw const AuthFlowException(
          'Phone verification has expired. Please resend the OTP.',
        );
      }

      try {
        await confirmationResult.confirm(code);
        _webConfirmationResult = null;
        await persistLastLoginMethod(AuthChannel.phone);
        return;
      } on FirebaseAuthException catch (error) {
        throw AuthFlowException(
          error.message ?? 'Failed to verify the phone OTP.',
        );
      }
    }

    if (session.verificationId == null || session.verificationId!.isEmpty) {
      throw const AuthFlowException('Phone verification has expired. Please resend the OTP.');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: session.verificationId!,
      smsCode: code,
    );

    try {
      await _auth.signInWithCredential(credential);
      await persistLastLoginMethod(AuthChannel.phone);
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(
        error.message ?? 'Failed to verify the phone OTP.',
      );
    }
  }

  Future<AuthOtpSession> startBackendOtp({
    required AuthChannel channel,
    required String identifier,
  }) async {
    final normalizedIdentifier = channel == AuthChannel.email
        ? normalizeEmail(identifier)
        : normalizePhone(identifier);
    final endpoint = channel == AuthChannel.email
        ? '/auth/email/send'
        : '/auth/whatsapp/send';
    final payload = channel == AuthChannel.email
        ? {'email': normalizedIdentifier}
        : {'phone': normalizedIdentifier};

    final json = await _postJson(endpoint, payload);
    return AuthOtpSession(
      channel: channel,
      identifier: normalizedIdentifier,
      destinationHint:
          (json['destinationHint'] ?? normalizedIdentifier).toString(),
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 300,
      devOtpHint: json['devOtpHint']?.toString(),
    );
  }

  Future<AuthOtpSession> resendBackendOtp(AuthOtpSession session) {
    return startBackendOtp(
      channel: session.channel,
      identifier: session.identifier,
    );
  }

  Future<void> verifyBackendOtp(AuthOtpSession session, String otp) async {
    final code = _normalizeOtp(otp);
    final endpoint = session.channel == AuthChannel.email
        ? '/auth/email/verify'
        : '/auth/whatsapp/verify';
    final payload = session.channel == AuthChannel.email
        ? {
            'email': session.identifier,
            'otp': code,
          }
        : {
            'phone': session.identifier,
            'otp': code,
          };

    final json = await _postJson(endpoint, payload);
    final customToken = json['customToken']?.toString();
    if (customToken == null || customToken.isEmpty) {
      throw const AuthFlowException('Missing Firebase custom token from the server.');
    }

    try {
      await _auth.signInWithCustomToken(customToken);
      await persistLastLoginMethod(session.channel);
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(
        error.message ?? 'Failed to complete Firebase sign-in.',
      );
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('${apiBaseUrl.replaceAll(RegExp(r'/$'), '')}$endpoint');
    http.Response response;

    try {
      response = await http.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } on http.ClientException catch (error) {
      throw AuthFlowException(
        'Cannot reach the auth API at $uri. Make sure Firebase Functions is deployed and CORS is enabled. Details: ${error.message}',
      );
    } on PlatformException catch (error) {
      throw AuthFlowException(
        'Platform error while calling $uri: ${error.message ?? error.code}',
      );
    } catch (error) {
      throw AuthFlowException(
        'Network error while calling $uri. Make sure the authApi Firebase Function is deployed and reachable. Details: $error',
      );
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AuthFlowException('The server returned an invalid response.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthFlowException(
        json['message']?.toString() ?? 'Request failed with status ${response.statusCode}.',
      );
    }

    return json;
  }

  Future<_PhoneVerificationData> _requestPhoneVerification(
    String phoneNumber, {
    int? resendToken,
  }) async {
    final completer = Completer<_PhoneVerificationData>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        if (kDebugMode) {
          debugPrint('Phone verification completed automatically.');
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(
            AuthFlowException(
              error.message ?? 'Failed to send OTP to the phone number.',
            ),
          );
        }
      },
      codeSent: (verificationId, newResendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            _PhoneVerificationData(
              verificationId: verificationId,
              resendToken: newResendToken,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.complete(
            _PhoneVerificationData(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        }
      },
    );

    return completer.future;
  }

  Future<_PhoneVerificationData> _requestPhoneVerificationWeb(
    String phoneNumber,
  ) async {
    try {
      _webConfirmationResult = null;
      final confirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);

      _webConfirmationResult = confirmationResult;

      return _PhoneVerificationData(
        verificationId: confirmationResult.verificationId,
        resendToken: null,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(
        error.message ??
            'Failed to start web phone verification. Check Firebase authorized domains and try again.',
      );
    }
  }

  String _normalizeOtp(String otp) {
    final code = otp.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      throw const AuthFlowException('Enter the 6-digit OTP.');
    }
    return code;
  }
}

class _PhoneVerificationData {
  const _PhoneVerificationData({
    required this.verificationId,
    this.resendToken,
  });

  final String verificationId;
  final int? resendToken;
}
