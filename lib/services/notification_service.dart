import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Initialize platform-specific settings, create Android channel, and
  /// request permissions on iOS/macOS.
  Future<void> init({Function(String? payload)? onSelectNotification}) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinInit = DarwinInitializationSettings();

    final settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (onSelectNotification != null) onSelectNotification(payload);
      },
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'triconnect_channel',
        'TriConnect',
        description: 'App notifications for TriConnect',
        importance: Importance.max,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Request permissions on iOS and macOS
    await _plugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
      .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Show an immediate notification. Provide optional `payload` for tap handling.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'triconnect_channel',
      'TriConnect',
      channelDescription: 'App notifications for TriConnect',
      importance: Importance.max,
      priority: Priority.high,
    );

    final darwinDetails = DarwinNotificationDetails();

    final platform = NotificationDetails(android: androidDetails, iOS: darwinDetails, macOS: darwinDetails);
    await _plugin.show(id, title, body, platform, payload: payload);
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) => _plugin.cancel(id);

  /// Cancel all notifications
  Future<void> cancelAll() => _plugin.cancelAll();
}
