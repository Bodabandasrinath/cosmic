import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background FCM handling
  if (kDebugMode) {
    print('Cosmic Background FCM: ${message.messageId}');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Function(Map<String, dynamic>)? onNotificationPayload;
  Function(Map<String, dynamic>)? onCallPayload;

  Future<void> initialize() async {
    // 1. Request Notification Permissions
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('FCM Permission status: ${settings.authorizationStatus}');
    }

    // 2. Initialize Android Local Notification Channels
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          try {
            final payloadMap = jsonDecode(response.payload!) as Map<String, dynamic>;
            if (payloadMap['type'] == 'incoming_call') {
              onCallPayload?.call(payloadMap);
            } else {
              onNotificationPayload?.call(payloadMap);
            }
          } catch (_) {}
        }
      },
    );

    // Create high importance channels
    const AndroidNotificationChannel messagesChannel = AndroidNotificationChannel(
      'cosmic_messages_channel',
      'Cosmic Messages',
      description: 'Notifications for new messages and photos',
      importance: Importance.high,
      enableVibration: true,
    );

    const AndroidNotificationChannel callsChannel = AndroidNotificationChannel(
      'cosmic_calls_channel',
      'Cosmic Calls',
      description: 'Incoming voice and video call alerts',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('call_ringtone'),
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(messagesChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(callsChannel);

    // 3. Foreground FCM listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // 4. Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. App opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['type'] == 'incoming_call') {
        onCallPayload?.call(message.data);
      } else {
        onNotificationPayload?.call(message.data);
      }
    });
  }

  Future<String?> getFCMToken() async {
    try {
      return await _fcm.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final isCall = data['type'] == 'incoming_call';
    final channelId = isCall ? 'cosmic_calls_channel' : 'cosmic_messages_channel';
    final channelName = isCall ? 'Cosmic Calls' : 'Cosmic Messages';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: isCall ? Importance.max : Importance.high,
      priority: isCall ? Priority.max : Priority.high,
      category: isCall ? AndroidNotificationCategory.call : AndroidNotificationCategory.message,
      fullScreenIntent: isCall,
    );

    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      notification?.title ?? (isCall ? 'Incoming Call' : 'New Message'),
      notification?.body ?? data['body'] ?? '',
      details,
      payload: jsonEncode(data),
    );
  }

  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}
