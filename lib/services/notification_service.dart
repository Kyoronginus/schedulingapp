import 'dart:async';
import 'dart:convert'; // Added for json.decode
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:schedulingapp/models/Schedule.dart';
import 'package:schedulingapp/models/Notification.dart';
import 'package:schedulingapp/models/NotificationType.dart';
import 'package:schedulingapp/models/GroupInvitation.dart';
import 'package:schedulingapp/services/timezone_service.dart';
import 'package:schedulingapp/models/User.dart';

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

  static Future<bool> markAsUnread(String notificationId) async {
  try {
    // Tulis logika untuk update ke backend/database Anda di sini, 
    // set 'isRead' menjadi false.
    // Contoh: await apiClient.post('/notifications/$notificationId/unread');
    print('Notification $notificationId marked as UNREAD in the backend.');
    return true; // Kembalikan true jika berhasil
  } catch (e) {
    print('Failed to mark notification as unread: $e');
    return false; // Kembalikan false jika gagal
  }
}
  // Load notifications from Amplify backend using GraphQL API
  static Future<void> _loadNotifications() async {
    try {
      _cachedNotifications = [];

      if (_currentUserId == null) {
        debugPrint('❌ Cannot load notifications: No current user');
        return;
      }

      // First, get user's group memberships to filter schedule notifications
      const userGroupsQuery = '''
        query GetUserGroups(\$userId: ID!) {
          listGroupUsers(filter: {userId: {eq: \$userId}}) {
            items {
              groupId
            }
          }
        }
      ''';

      final userGroupsRequest = GraphQLRequest<String>(
        document: userGroupsQuery,
        variables: {'userId': _currentUserId},
      );
      final userGroupsResponse = await Amplify.API.query(request: userGroupsRequest).response;

      if (userGroupsResponse.hasErrors) {
        debugPrint('Error getting user groups: ${userGroupsResponse.errors.first.message}');
        return;
      }

      // Extract group IDs that the user is a member of
      final userGroupsData = json.decode(userGroupsResponse.data ?? '{}');
      final userGroupItems = userGroupsData['listGroupUsers']?['items'] ?? [];
      final userGroupIds = userGroupItems.map<String>((item) => item['groupId'] as String).toList();

      debugPrint('🔍 User $_currentUserId is member of groups: $userGroupIds');

      // Now fetch notifications with proper filtering
      // 1. Invitation notifications where the user is the invited user
      // 2. Schedule notifications where the schedule belongs to a group the user is a member of

      List<Notification> allNotifications = [];

      // First, get all group invitations for this user to get their IDs
      const userInvitationsQuery = '''
        query GetUserInvitations(\$userId: ID!) {
          listGroupInvitations(filter: {invitedUserId: {eq: \$userId}}) {
            items {
              id
            }
          }
        }
      ''';

      final userInvitationsRequest = GraphQLRequest<String>(
        document: userInvitationsQuery,
        variables: {'userId': _currentUserId},
      );
      final userInvitationsResponse = await Amplify.API.query(request: userInvitationsRequest).response;

      List<String> userInvitationIds = [];
      if (!userInvitationsResponse.hasErrors) {
        final invitationsData = json.decode(userInvitationsResponse.data ?? '{}');
        final invitationItems = invitationsData['listGroupInvitations']?['items'] ?? [];
        userInvitationIds = invitationItems.map<String>((item) => item['id'] as String).toList();
      }

      // Fetch invitation notifications using the invitation IDs
      if (userInvitationIds.isNotEmpty) {
        for (final invitationId in userInvitationIds) {
          const invitationNotificationsQuery = '''
            query GetInvitationNotifications(\$invitationId: ID!) {
              listNotifications(filter: {
                and: [
                  {type: {eq: INVITATION}},
                  {groupInvitationId: {eq: \$invitationId}}
                ]
              }) {
                items {
                  id
                  type
                  isRead
                  timestamp
                  scheduleId
                  groupInvitationId
                  readByUsers
                  groupInvitation {
                    id
                    status
                    isAdmin
                    invitedUserId
                    group {
                      id
                      name
                    }
                    invitedByUser {
                      id
                      name
                      email
                      primaryAuthMethod
                      linkedAuthMethods
                    }
                  }
                }
              }
            }
          ''';

          final invitationRequest = GraphQLRequest<String>(
            document: invitationNotificationsQuery,
            variables: {'invitationId': invitationId},
          );
          final invitationResponse = await Amplify.API.query(request: invitationRequest).response;

          if (invitationResponse.hasErrors) {
            debugPrint('Error loading invitation notifications for invitation $invitationId: ${invitationResponse.errors.first.message}');
            continue;
          }

          final invitationData = json.decode(invitationResponse.data ?? '{}');
          final invitationItems = invitationData['listNotifications']?['items'] ?? [];

          for (final item in invitationItems) {
            try {
              final notification = Notification.fromJson(item);
              // Avoid duplicates
              if (!allNotifications.any((n) => n.id == notification.id)) {
                allNotifications.add(notification);
              }
            } catch (e) {
              debugPrint('❌ Error parsing invitation notification: $e');
            }
          }
        }
      }

      // Fetch schedule notifications for groups the user is a member of
      if (userGroupIds.isNotEmpty) {
        for (final groupId in userGroupIds) {
          // First get all schedules for this group
          const groupSchedulesQuery = '''
            query GetGroupSchedules(\$groupId: ID!) {
              listSchedules(filter: {groupId: {eq: \$groupId}}) {
                items {
                  id
                }
              }
            }
          ''';

          final groupSchedulesRequest = GraphQLRequest<String>(
            document: groupSchedulesQuery,
            variables: {'groupId': groupId},
          );
          final groupSchedulesResponse = await Amplify.API.query(request: groupSchedulesRequest).response;

          if (groupSchedulesResponse.hasErrors) {
            debugPrint('Error loading schedules for group $groupId: ${groupSchedulesResponse.errors.first.message}');
            continue;
          }

          final schedulesData = json.decode(groupSchedulesResponse.data ?? '{}');
          final scheduleItems = schedulesData['listSchedules']?['items'] ?? [];
          final scheduleIds = scheduleItems.map<String>((item) => item['id'] as String).toList();

          // Now fetch notifications for these schedules
          for (final scheduleId in scheduleIds) {
            const scheduleNotificationsQuery = '''
              query GetScheduleNotifications(\$scheduleId: ID!) {
                listNotifications(filter: {
                  and: [
                    {type: {ne: INVITATION}},
                    {scheduleId: {eq: \$scheduleId}}
                  ]
                }) {
                  items {
                    id
                    type
                    isRead
                    timestamp
                    scheduleId
                    groupInvitationId
                    readByUsers
                    schedule {
                      id
                      title
                      startTime
                      endTime
                      groupId
                      user {
                        id
                        name
                        email
                        primaryAuthMethod
                        linkedAuthMethods
                      }
                    }
                  }
                }
              }
            ''';

            final scheduleRequest = GraphQLRequest<String>(
              document: scheduleNotificationsQuery,
              variables: {'scheduleId': scheduleId},
            );
            final scheduleResponse = await Amplify.API.query(request: scheduleRequest).response;

            if (scheduleResponse.hasErrors) {
              debugPrint('Error loading notifications for schedule $scheduleId: ${scheduleResponse.errors.first.message}');
              continue;
            }

            final scheduleData = json.decode(scheduleResponse.data ?? '{}');
            final notificationItems = scheduleData['listNotifications']?['items'] ?? [];

            for (final item in notificationItems) {
              try {
                final notification = Notification.fromJson(item);
                // Avoid duplicates
                if (!allNotifications.any((n) => n.id == notification.id)) {
                  allNotifications.add(notification);
                }
              } catch (e) {
                debugPrint('❌ Error parsing schedule notification: $e');
              }
            }
          }
        }
      }

      // Process notifications to set correct isRead status for current user
      final processedNotifications = allNotifications.map((notification) {
        // Check if current user is in readByUsers array
        final isReadByCurrentUser = notification.readByUsers?.contains(_currentUserId) ?? false;

        debugPrint('🔍 Processing notification ${notification.id}: readByUsers=${notification.readByUsers}, currentUser=$_currentUserId, isReadByCurrentUser=$isReadByCurrentUser');

        // Return notification with corrected isRead status
        return notification.copyWith(isRead: isReadByCurrentUser);
      }).toList();

      _cachedNotifications = processedNotifications;

      // Sort notifications by timestamp (newest first) - using local time for comparison
      _cachedNotifications.sort((a, b) =>
        TimezoneService.utcToLocal(b.timestamp).compareTo(TimezoneService.utcToLocal(a.timestamp)));

      debugPrint('✅ Loaded ${_cachedNotifications.length} notifications for user $_currentUserId');
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

  // Get notifications for a specific group
  static Future<List<Notification>> getNotificationsForGroup(String groupId) async {
    await initialize(); // Ensure service is initialized

    try {
      if (_currentUserId == null) {
        debugPrint('❌ Cannot load group notifications: No current user');
        return [];
      }

      List<Notification> groupNotifications = [];

      // Get invitation notifications for this specific group
      const groupInvitationsQuery = '''
        query GetGroupInvitations(\$userId: ID!, \$groupId: ID!) {
          listGroupInvitations(filter: {
            and: [
              {invitedUserId: {eq: \$userId}},
              {groupId: {eq: \$groupId}}
            ]
          }) {
            items {
              id
            }
          }
        }
      ''';

      final groupInvitationsRequest = GraphQLRequest<String>(
        document: groupInvitationsQuery,
        variables: {'userId': _currentUserId, 'groupId': groupId},
      );
      final groupInvitationsResponse = await Amplify.API.query(request: groupInvitationsRequest).response;

      List<String> groupInvitationIds = [];
      if (!groupInvitationsResponse.hasErrors) {
        final invitationsData = json.decode(groupInvitationsResponse.data ?? '{}');
        final invitationItems = invitationsData['listGroupInvitations']?['items'] ?? [];
        groupInvitationIds = invitationItems.map<String>((item) => item['id'] as String).toList();
      }

      // Fetch invitation notifications for this group
      for (final invitationId in groupInvitationIds) {
        const invitationNotificationsQuery = '''
          query GetInvitationNotifications(\$invitationId: ID!) {
            listNotifications(filter: {
              and: [
                {type: {eq: INVITATION}},
                {groupInvitationId: {eq: \$invitationId}}
              ]
            }) {
              items {
                id
                type
                isRead
                timestamp
                scheduleId
                groupInvitationId
                readByUsers
                groupInvitation {
                  id
                  status
                  isAdmin
                  invitedUserId
                  group {
                    id
                    name
                  }
                  invitedByUser {
                    id
                    name
                    email
                    primaryAuthMethod
                    linkedAuthMethods
                  }
                }
              }
            }
          }
        ''';

        final invitationRequest = GraphQLRequest<String>(
          document: invitationNotificationsQuery,
          variables: {'invitationId': invitationId},
        );
        final invitationResponse = await Amplify.API.query(request: invitationRequest).response;

        if (!invitationResponse.hasErrors) {
          final invitationData = json.decode(invitationResponse.data ?? '{}');
          final invitationItems = invitationData['listNotifications']?['items'] ?? [];

          for (final item in invitationItems) {
            try {
              final notification = Notification.fromJson(item);
              if (!groupNotifications.any((n) => n.id == notification.id)) {
                groupNotifications.add(notification);
              }
            } catch (e) {
              debugPrint('❌ Error parsing group invitation notification: $e');
            }
          }
        }
      }

      // Get schedule notifications for this specific group
      const groupSchedulesQuery = '''
        query GetGroupSchedules(\$groupId: ID!) {
          listSchedules(filter: {groupId: {eq: \$groupId}}) {
            items {
              id
            }
          }
        }
      ''';

      final groupSchedulesRequest = GraphQLRequest<String>(
        document: groupSchedulesQuery,
        variables: {'groupId': groupId},
      );
      final groupSchedulesResponse = await Amplify.API.query(request: groupSchedulesRequest).response;

      if (!groupSchedulesResponse.hasErrors) {
        final schedulesData = json.decode(groupSchedulesResponse.data ?? '{}');
        final scheduleItems = schedulesData['listSchedules']?['items'] ?? [];
        final scheduleIds = scheduleItems.map<String>((item) => item['id'] as String).toList();

        // Fetch notifications for these schedules
        for (final scheduleId in scheduleIds) {
          const scheduleNotificationsQuery = '''
            query GetScheduleNotifications(\$scheduleId: ID!) {
              listNotifications(filter: {
                and: [
                  {type: {ne: INVITATION}},
                  {scheduleId: {eq: \$scheduleId}}
                ]
              }) {
                items {
                  id
                  type
                  isRead
                  timestamp
                  scheduleId
                  groupInvitationId
                  readByUsers
                  schedule {
                    id
                    title
                    startTime
                    endTime
                    groupId
                    user {
                      id
                      name
                      email
                      primaryAuthMethod
                      linkedAuthMethods
                    }
                  }
                }
              }
            }
          ''';

          final scheduleRequest = GraphQLRequest<String>(
            document: scheduleNotificationsQuery,
            variables: {'scheduleId': scheduleId},
          );
          final scheduleResponse = await Amplify.API.query(request: scheduleRequest).response;

          if (!scheduleResponse.hasErrors) {
            final scheduleData = json.decode(scheduleResponse.data ?? '{}');
            final notificationItems = scheduleData['listNotifications']?['items'] ?? [];

            for (final item in notificationItems) {
              try {
                final notification = Notification.fromJson(item);
                if (!groupNotifications.any((n) => n.id == notification.id)) {
                  groupNotifications.add(notification);
                }
              } catch (e) {
                debugPrint('❌ Error parsing group schedule notification: $e');
              }
            }
          }
        }
      }

      // Process notifications to set correct isRead status for current user
      final processedNotifications = groupNotifications.map((notification) {
        final isReadByCurrentUser = notification.readByUsers?.contains(_currentUserId) ?? false;
        return notification.copyWith(isRead: isReadByCurrentUser);
      }).toList();

      // Sort notifications by timestamp (newest first)
      processedNotifications.sort((a, b) =>
        TimezoneService.utcToLocal(b.timestamp).compareTo(TimezoneService.utcToLocal(a.timestamp)));

      debugPrint('✅ Loaded ${processedNotifications.length} notifications for group $groupId');
      return processedNotifications;
    } catch (e) {
      debugPrint('❌ Error loading group notifications: $e');
      return [];
    }
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
        // Note: Cache will be refreshed when user navigates to notification screen
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
        // Note: Cache will be refreshed when user navigates to notification screen
      }
    } catch (e) {
      debugPrint('Error creating upcoming notification: $e');
    }
  }

  // Add a notification for a group invitation
  static Future<void> addGroupInvitationNotification(GroupInvitation invitation) async {
    await initialize();

    try {
      // Validate that the invitation has a valid ID
      if (invitation.id.isEmpty) {
        debugPrint('❌ Cannot create invitation notification: Invitation ID is empty');
        return;
      }

      debugPrint('🔔 Creating invitation notification for invitation: ${invitation.id}');

      final message = NotificationService.getNotificationMessage(Notification(
        groupInvitation: invitation,
        type: NotificationType.INVITATION,
        timestamp: TemporalDateTime.now(),
        isRead: false,
      ));

      // Create the notification using GraphQL API
      final notification = Notification(
        groupInvitation: invitation,
        type: NotificationType.INVITATION,
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
              groupInvitationId
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
            'groupInvitationId': invitation.id,
            'message': notification.message,
            'readByUsers': [], // Initialize empty array
          },
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.hasErrors) {
        debugPrint('❌ Error creating invitation notification: ${response.errors.first.message}');
        debugPrint('❌ Full error details: ${response.errors}');
      } else {
        debugPrint('✅ Invitation notification created successfully: ${response.data}');
        // Note: Cache will be refreshed when user navigates to notification screen
      }
    } catch (e) {
      debugPrint('Error creating invitation notification: $e');
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

  /// Helper method to resolve user display name with OAuth-aware fallback
  static String _resolveUserDisplayName(User? user) {
    if (user == null) return 'Someone';

    // If user has a name, use it
    if (user.name.isNotEmpty) {
      return user.name;
    }

    // Fallback to email prefix for OAuth users
    if (user.email.isNotEmpty) {
      return user.email.split('@')[0];
    }

    // Last resort fallback
    return 'Someone';
  }

  // Get message for a notification
  static String getNotificationMessage(Notification notification) {
    switch (notification.type) {
      case NotificationType.CREATED:
        final userName = _resolveUserDisplayName(notification.schedule?.user);
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
      case NotificationType.INVITATION:
        final inviterName = _resolveUserDisplayName(notification.groupInvitation?.invitedByUser);
        final groupName = notification.groupInvitation?.group?.name ?? 'a group';
        final role = notification.groupInvitation?.isAdmin == true ? 'admin' : 'member';
        return '$inviterName invited you to join "$groupName" as $role';
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
