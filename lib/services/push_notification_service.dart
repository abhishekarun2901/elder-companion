import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();

  factory PushNotificationService() {
    return _instance;
  }

  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // 1. Request permissions for iOS etc
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // 2. Get the token
    final token = await _fcm.getToken();
    if (token != null) {
      debugPrint("FCM Token: $token");
      await _saveTokenToFirestore(token);
    }

    // 3. Listen for token refreshes
    _fcm.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestore(newToken);
    });

    // 4. Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        
        // Show local notification
        NotificationService().showInstantNotification(
           id: message.hashCode, 
           title: message.notification?.title ?? "Alert", 
           body: message.notification?.body ?? ""
        );
      }
    });
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('FCM Token saved to Firestore for user: ${user.uid}');
    }
  }
}
