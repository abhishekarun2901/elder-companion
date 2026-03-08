
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../main.dart'; // Access navigatorKey
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  final FlutterTts flutterTts = FlutterTts();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint("Could not get local timezone: $e");
      // Fallback to UTC or a default if needed, or just let it use UTC default
      tz.setLocalLocation(tz.getLocation('UTC')); 
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        if (response.payload != null) {
          _speak(response.payload!); // Speak the payload (message)
        }
      },
    );

    // Request Permissions
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true, 
          badge: true, 
          sound: true,
        );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_channel',
          'Medication Reminders',
          channelDescription: 'Reminders to take medication',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: matchDateTimeComponents,
      payload: "$title. $body", // Payload is what is spoken
    );
     debugPrint("Scheduled notification for $scheduledTime");

     // Fallback for Web or Foreground simple handling
    if (kIsWeb) {
      final now = DateTime.now();
      var difference = scheduledTime.difference(now);
      
      // If time has passed today, assume it's for tomorrow if daily, else return
      if (difference.isNegative) {
          if (matchDateTimeComponents == DateTimeComponents.time) {
             difference += const Duration(days: 1);
          } else {
             return;
          }
      }

      Timer(difference, () {
        _speak("$title. $body");
        _showNotificationDialog(title, body);
        
        // If daily, schedule next one (simple recursion/periodic simulation)
        if (matchDateTimeComponents == DateTimeComponents.time) {
            // Ideally we'd set a periodic timer, but for now just one-off for the next day 
            // is tricky without keeping state. Detailed web recurrence is complex.
            // We will leave it as one-time for this simple fallback or user refreshes.
        }
      });
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> showInstantNotification({
      required int id,
      required String title,
      required String body
  }) async {
      const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails('instant_channel', 'Instant Notifications',
          channelDescription: 'Instant alerts',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker');
      const NotificationDetails notificationDetails =
      NotificationDetails(android: androidNotificationDetails);
      await flutterLocalNotificationsPlugin.show(
          id: id, 
          title: title, 
          body: body, 
          notificationDetails: notificationDetails,
          payload: "$title. $body"
      );
      _speak("$title. $body");
      // Show visual dialog
      _showNotificationDialog(title, body);
  }


  Future<void> _speak(String text) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(text);
  }

  void _showNotificationDialog(String title, String body) {
    // Only show if we have a valid context
    if (navigatorKey.currentState?.context == null) return;

    showDialog(
      context: navigatorKey.currentState!.context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () {
               flutterTts.stop();
               Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
