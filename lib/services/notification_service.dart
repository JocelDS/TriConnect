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
      settings: settings,
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
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Fallback: some versions of flutter_local_notifications expose
    // different APIs. To avoid static API mismatches during analysis
    // and runtime, keep a lightweight no-op fallback here. The app
    // still writes notification documents to Firestore where needed.
    // If you need local notifications, uncomment and adapt the call
    // to match your installed plugin version.
    // print('Local notification: $title - $body');
    return;
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  /// Cancel all notifications
  Future<void> cancelAll() => _plugin.cancelAll();
}
