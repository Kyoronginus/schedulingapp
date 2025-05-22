import 'dart:async';
import 'package:schedulingapp/models/Schedule.dart';
import 'package:schedulingapp/models/NotificationModel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class NotificationService {
  static const String _notificationsKey = 'notifications';
  static List<NotificationModel> _notifications = [];
  static bool _isInitialized = false;

  // Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadNotifications();
    _isInitialized = true;
  }

  // Load notifications from shared preferences
  static Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJsonList = prefs.getStringList(_notificationsKey) ?? [];

      _notifications = [];

      // Convert stored JSON strings back to notification objects
      for (final jsonStr in notificationsJsonList) {
        try {
          final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);

          // Extract schedule data from the JSON
          final scheduleJson = jsonMap['schedule'];
          if (scheduleJson == null) continue;

          // Create Schedule object
          final schedule = Schedule.fromJson(scheduleJson);

          // Create NotificationModel
          final notification = NotificationModel(
            id: jsonMap['id'],
            schedule: schedule,
            type: NotificationType.values[jsonMap['type']],
            timestamp: DateTime.parse(jsonMap['timestamp']),
            isRead: jsonMap['isRead'] ?? false,
          );

          _notifications.add(notification);
        } catch (e) {
          debugPrint('Error parsing notification: $e');
        }
      }

      // Sort notifications by timestamp (newest first)
      _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  // Save notifications to shared preferences
  static Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final notificationsJsonList = _notifications.map((notification) {
        // Convert notification to a serializable map
        final Map<String, dynamic> notificationMap = {
          'id': notification.id,
          'schedule': notification.schedule.toJson(),
          'type': notification.type.index,
          'timestamp': notification.timestamp.toIso8601String(),
          'isRead': notification.isRead,
        };

        // Convert map to JSON string
        return jsonEncode(notificationMap);
      }).toList();

      await prefs.setStringList(_notificationsKey, notificationsJsonList);
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  // Get all notifications
  static Future<List<NotificationModel>> getNotifications() async {
    await initialize();
    return _notifications;
  }

  // Add a notification for a newly created schedule
  static Future<void> addCreatedScheduleNotification(Schedule schedule) async {
    await initialize();

    final notification = NotificationModel.forCreatedSchedule(schedule);
    _notifications.add(notification);

    await _saveNotifications();
  }

  // Add a notification for an upcoming schedule
  static Future<void> addUpcomingScheduleNotification(Schedule schedule) async {
    await initialize();

    final notification = NotificationModel.forUpcomingSchedule(schedule);
    _notifications.add(notification);

    await _saveNotifications();
  }

  // Mark a notification as read
  static Future<void> markAsRead(String notificationId) async {
    await initialize();

    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveNotifications();
    }
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead() async {
    await initialize();

    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    await _saveNotifications();
  }

  // Get real notifications (for backward compatibility with the sample method)
  static Future<List<NotificationModel>> getSampleNotifications() async {
    return getNotifications();
  }
}
