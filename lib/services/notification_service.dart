import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._privateConstructor();
  static final NotificationService _instance = NotificationService._privateConstructor();
  factory NotificationService() => _instance;

  Future<void> init() async {
    debugPrint('Notifications are disabled in this build.');
  }

  Future<void> showNotification({required int id, required String title, required String body}) async {
    debugPrint('Notification: $title - $body');
  }
}
