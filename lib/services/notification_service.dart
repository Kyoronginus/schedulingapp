import 'dart:async';
import 'dart:convert'; // Added for json.decode
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:schedulingapp/models/Schedule.dart';
import 'package:schedulingapp/models/Notification.dart';
import 'package:schedulingapp/models/NotificationType.dart';
import 'package:schedulingapp/services/timezone_service.dart';

import 'package:flutter/foundation.dart';

class NotificationService {
  static List<Notification> _cachedNotifications = [];
  static bool _isInitialized = false;
  static String? _currentUserId;

  // Initialize the notification service
  static Future<void> initialize() async {
    // Get current user ID for session management
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final newUserId = user.userId;

      // If user changed, clear cache and reinitialize
      if (_currentUserId != newUserId) {
        _cachedNotifications.clear();
        _currentUserId = newUserId;
        _isInitialized = false;
      }
    } catch (e) {
      debugPrint('Error getting current user in NotificationService: $e');
      _currentUserId = null;
    }

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
              readByUsers
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

          // Check if current user has read this notification
          final readByUsers = item['readByUsers'] as List<dynamic>? ?? [];

          // For backward compatibility: if readByUsers is empty and isRead is true,
          // treat it as read by all users (legacy behavior)
          final legacyIsRead = item['isRead'] as bool? ?? false;
          final isReadByCurrentUser = _currentUserId != null &&
              (readByUsers.contains(_currentUserId) ||
               (readByUsers.isEmpty && legacyIsRead));

          return Notification(
            id: item['id'],
            type: NotificationType.values.firstWhere((e) => e.name == item['type']),
            isRead: isReadByCurrentUser, // User-specific read state
            timestamp: TemporalDateTime(DateTime.parse(item['timestamp'])),
            schedule: schedule,
            message: item['message'],
            readByUsers: List<String>.from(readByUsers),
          );
        }).toList();

        // Sort notifications by timestamp (newest first) - using local time for comparison
        _cachedNotifications.sort((a, b) =>
          TimezoneService.utcToLocal(b.timestamp).compareTo(TimezoneService.utcToLocal(a.timestamp)));
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
      // Validate that the schedule has a valid ID
      if (schedule.id.isEmpty) {
        debugPrint('❌ Cannot create notification: Schedule ID is empty');
        return;
      }

      debugPrint('🔔 Creating notification for schedule: ${schedule.id}');

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
        readByUsers: [], // Initialize empty array
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
              readByUsers
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
            'readByUsers': [], // Initialize empty array
          },
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.hasErrors) {
        debugPrint('❌ Error creating notification: ${response.errors.first.message}');
        debugPrint('❌ Full error details: ${response.errors}');
      } else {
        debugPrint('✅ Notification created successfully: ${response.data}');
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
      // Validate that the schedule has a valid ID
      if (schedule.id.isEmpty) {
        debugPrint('❌ Cannot create upcoming notification: Schedule ID is empty');
        return;
      }

      debugPrint('🔔 Creating upcoming notification for schedule: ${schedule.id}');

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
        readByUsers: [], // Initialize empty array
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
              readByUsers
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
            'readByUsers': [], // Initialize empty array
          },
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.hasErrors) {
        debugPrint('❌ Error creating upcoming notification: ${response.errors.first.message}');
        debugPrint('❌ Full error details: ${response.errors}');
      } else {
        debugPrint('✅ Upcoming notification created successfully: ${response.data}');
        await _loadNotifications(); // Refresh cache from backend
      }
    } catch (e) {
      debugPrint('Error creating upcoming notification: $e');
    }
  }

  // Mark a notification as read for the current user
  static Future<bool> markAsRead(String notificationId) async {
    await initialize();

    if (_currentUserId == null) {
      debugPrint('❌ Cannot mark notification as read: No current user');
      return false;
    }

    try {
      // First, get the current notification to get existing readByUsers
      const getNotificationQuery = '''
        query GetNotification(\$id: ID!) {
          getNotification(id: \$id) {
            id
            readByUsers
          }
        }
      ''';

      final getRequest = GraphQLRequest<String>(
        document: getNotificationQuery,
        variables: {'id': notificationId},
      );

      final getResponse = await Amplify.API.query(request: getRequest).response;
      if (getResponse.hasErrors) {
        debugPrint('❌ Error getting notification: ${getResponse.errors.first.message}');
        return false;
      }

      final data = getResponse.data;
      if (data == null) {
        debugPrint('❌ No notification data found');
        return false;
      }

      final notificationData = json.decode(data)['getNotification'];
      final currentReadByUsers = List<String>.from(notificationData['readByUsers'] ?? []);

      // Add current user to readByUsers if not already present
      if (!currentReadByUsers.contains(_currentUserId)) {
        currentReadByUsers.add(_currentUserId!);
      }

      // Update the notification with the new readByUsers array
      const updateNotificationMutation = '''
        mutation UpdateNotification(\$input: UpdateNotificationInput!) {
          updateNotification(input: \$input) {
            id
            readByUsers
          }
        }
      ''';

      final updateRequest = GraphQLRequest<String>(
        document: updateNotificationMutation,
        variables: {
          'input': {
            'id': notificationId,
            'readByUsers': currentReadByUsers,
          },
        },
      );

      final updateResponse = await Amplify.API.mutate(request: updateRequest).response;
      if (updateResponse.hasErrors) {
        debugPrint('❌ Error marking notification as read: ${updateResponse.errors.first.message}');
        return false;
      } else {
        debugPrint('✅ Notification marked as read for user: $_currentUserId');
        // Update cache
        final index = _cachedNotifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _cachedNotifications[index] = _cachedNotifications[index].copyWith(
            isRead: true, // Mark as read for current user
            readByUsers: currentReadByUsers,
          );
        }
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      return false;
    }
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead() async {
    await initialize();

    try {
      final List<Notification> notificationsToUpdate = _cachedNotifications.where((n) => !n.isRead).toList();

      for (final notification in notificationsToUpdate) {
        await markAsRead(notification.id);
      }

      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  // Get message for a notification
  static String getNotificationMessage(Notification notification) {
    switch (notification.type) {
      case NotificationType.CREATED:
        final userName = notification.schedule?.user?.name ?? 'Someone';
        return '$userName created an event ${_getTimeAgo(TimezoneService.utcToLocal(notification.timestamp))}';
      case NotificationType.UPCOMING:
        final startTimeLocal = TimezoneService.utcToLocal(notification.schedule!.startTime);
        final now = DateTime.now();
        final difference = startTimeLocal.difference(now);

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

  /// Clear all cached notifications (for session cleanup)
  static void clearCache() {
    _cachedNotifications.clear();
    _isInitialized = false;
    _currentUserId = null;
    debugPrint('✅ Notification cache cleared');
  }

  /// Delete a specific notification
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      const deleteNotificationMutation = '''
        mutation DeleteNotification(\$input: DeleteNotificationInput!) {
          deleteNotification(input: \$input) {
            id
          }
        }
      ''';

      final request = GraphQLRequest<String>(
        document: deleteNotificationMutation,
        variables: {
          'input': {
            'id': notificationId,
          }
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        debugPrint('❌ Error deleting notification: ${response.errors.first.message}');
        return false;
      } else {
        debugPrint('✅ Notification deleted successfully: $notificationId');
        // Remove from cache
        _cachedNotifications.removeWhere((n) => n.id == notificationId);
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      return false;
    }
  }
}
