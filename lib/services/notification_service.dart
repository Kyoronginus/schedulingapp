import 'dart:async';
import 'dart:convert'; // Added for json.decode
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:schedulingapp/models/Schedule.dart';
import 'package:schedulingapp/models/Notification.dart';
import 'package:schedulingapp/models/NotificationType.dart';
import 'package:schedulingapp/models/User.dart'; // Added for User model
import 'package:flutter/foundation.dart';

class NotificationService {
  static List<Notification> _cachedNotifications = [];
  static bool _isInitialized = false;

  // Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadNotifications();
    _isInitialized = true;
  }

  // Load notifications from Amplify backend using GraphQL API
  static Future<void> _loadNotifications() async {
    try {
      _cachedNotifications = [];

      const listNotificationsQuery = '''
        query ListNotifications {
          listNotifications {
            items {
              id
              type
              isRead
              timestamp
              scheduleId
              schedule {
                id
                title
                startTime
                endTime
                user {
                  id
                  name
                }
              }
            }
          }
        }
      ''';

      final request = GraphQLRequest<String>(document: listNotificationsQuery);
      final response = await Amplify.API.query(request: request).response;

      if (response.hasErrors) {
        debugPrint('Error listing notifications: ${response.errors.first.message}');
        return;
      }

      final data = response.data;
      if (data != null) {
        final Map<String, dynamic> jsonResponse = json.decode(data);
        final List<dynamic> notificationItems = jsonResponse['listNotifications']['items'];

        _cachedNotifications = notificationItems.map((item) {
          final scheduleData = item['schedule'];
          Schedule? schedule;
          if (scheduleData != null) {
            schedule = Schedule.fromJson(Map<String, dynamic>.from(scheduleData));
          }

          return Notification(
            id: item['id'],
            type: NotificationType.values.firstWhere((e) => e.name == item['type']),
            isRead: item['isRead'],
            timestamp: TemporalDateTime(DateTime.parse(item['timestamp'])),
            schedule: schedule,
            message: item['message'],
          );
        }).toList();

        // Sort notifications by timestamp (newest first)
        _cachedNotifications.sort((a, b) => b.timestamp.getDateTimeInUtc().compareTo(a.timestamp.getDateTimeInUtc()));
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  // Get all notifications
  static Future<List<Notification>> getNotifications() async {
    await initialize(); // Ensure service is initialized
    await _loadNotifications(); // Always load latest from backend
    return _cachedNotifications;
  }

  // Add a notification for a newly created schedule
  static Future<void> addCreatedScheduleNotification(Schedule schedule) async {
    await initialize();

    try {
      final message = NotificationService.getNotificationMessage(Notification(
        schedule: schedule,
        type: NotificationType.CREATED,
        timestamp: TemporalDateTime.now(),
        isRead: false,
      ));

      // Create the notification using GraphQL API
      final notification = Notification(
        schedule: schedule,
        type: NotificationType.CREATED,
        timestamp: TemporalDateTime.now(),
        isRead: false,
        message: message,
      );

      // Create notification in the cloud using GraphQL API
      final request = GraphQLRequest<String>(
        document: '''
          mutation CreateNotification(\$input: CreateNotificationInput!) {
            createNotification(input: \$input) {
              id
              type
              isRead
              timestamp
              scheduleId
              message
            }
          }
        ''',
        variables: {
          'input': {
            'type': notification.type.name,
            'isRead': notification.isRead,
            'timestamp': notification.timestamp.format(),
            'scheduleId': schedule.id,
            'message': notification.message,
          },
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.hasErrors) {
        debugPrint('Error creating notification: ${response.errors.first.message}');
      } else {
        debugPrint('✅ Notification created successfully');
        await _loadNotifications(); // Refresh cache from backend
      }
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  // Add a notification for an upcoming schedule
  static Future<void> addUpcomingScheduleNotification(Schedule schedule) async {
    await initialize();

    try {
      final message = NotificationService.getNotificationMessage(Notification(
        schedule: schedule,
        type: NotificationType.UPCOMING,
        timestamp: TemporalDateTime.now(),
        isRead: false,
      ));

      // Create the notification using GraphQL API
      final notification = Notification(
        id: '${schedule.id}_upcoming',
        schedule: schedule,
        type: NotificationType.UPCOMING,
        timestamp: TemporalDateTime.now(),
        isRead: false,
        message: message,
      );

      // Create notification in the cloud using GraphQL API
      final request = GraphQLRequest<String>(
        document: '''
          mutation CreateNotification(\$input: CreateNotificationInput!) {
            createNotification(input: \$input) {
              id
              type
              isRead
              timestamp
              scheduleId
              message
            }
          }
        ''',
        variables: {
          'input': {
            'id': notification.id,
            'type': notification.type.name,
            'isRead': notification.isRead,
            'timestamp': notification.timestamp.format(),
            'scheduleId': schedule.id,
            'message': notification.message,
          },
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.hasErrors) {
        debugPrint('Error creating notification: ${response.errors.first.message}');
      } else {
        debugPrint('✅ Notification created successfully');
        await _loadNotifications(); // Refresh cache from backend
      }
    } catch (e) {
      debugPrint('Error creating upcoming notification: $e');
    }
  }

  // Mark a notification as read
  static Future<void> markAsRead(String notificationId) async {
    await initialize();

    final index = _cachedNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final notification = _cachedNotifications[index];
      final updatedNotification = notification.copyWith(isRead: true);

      // Update notification in the cloud using GraphQL API
      final request = GraphQLRequest<String>(
        document: '''
          mutation UpdateNotification(\$input: UpdateNotificationInput!) {
            updateNotification(input: \$input) {
              id
              isRead
            }
          }
        ''',
        variables: {
          'input': {
            'id': notificationId,
            'isRead': true,
          },
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.hasErrors) {
        debugPrint('Error marking notification as read: ${response.errors.first.message}');
      } else {
        debugPrint('✅ Notification marked as read successfully');
        await _loadNotifications(); // Refresh cache from backend
      }
    }
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead() async {
    await initialize();

    final List<Notification> notificationsToUpdate = _cachedNotifications.where((n) => !n.isRead).toList();

    for (final notification in notificationsToUpdate) {
      final updatedNotification = notification.copyWith(isRead: true);

      // Update notification in the cloud using GraphQL API
      final request = GraphQLRequest<String>(
        document: '''
          mutation UpdateNotification(\$input: UpdateNotificationInput!) {
            updateNotification(input: \$input) {
              id
              isRead
            }
          }
        ''',
        variables: {
          'input': {
            'id': notification.id,
            'isRead': true,
          },
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.hasErrors) {
        debugPrint('Error marking notification as read: ${response.errors.first.message}');
      } else {
        debugPrint('✅ Notification marked as read successfully');
      }
    }
    await _loadNotifications(); // Refresh cache from backend after all updates
  }

  // Get message for a notification
  static String getNotificationMessage(Notification notification) {
    switch (notification.type) {
      case NotificationType.CREATED:
        final userName = notification.schedule?.user?.name ?? 'Someone';
        return '$userName created an event ${_getTimeAgo(notification.timestamp.getDateTimeInUtc())}';
      case NotificationType.UPCOMING:
        final startTime = notification.schedule!.startTime.getDateTimeInUtc();
        final now = DateTime.now();
        final difference = startTime.difference(now);

        if (difference.inHours < 1) {
          return 'Event will start in ${difference.inMinutes} minutes';
        } else if (difference.inHours < 24) {
          return 'Event will start in ${difference.inHours} hours';
        } else {
          return 'Event will start in ${difference.inDays} days';
        }
    }
  }

  // Get time ago for created notifications
  static String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  // Get real notifications (for backward compatibility with the sample method)
  static Future<List<Notification>> getSampleNotifications() async {
    return getNotifications();
  }
}
