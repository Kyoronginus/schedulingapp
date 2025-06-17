import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/refresh_controller.dart';
import '../models/Notification.dart' as models;
import '../models/NotificationType.dart';
import '../models/InvitationStatus.dart';
import '../services/notification_service.dart';
import '../services/timezone_service.dart';
import '../dynamo/group_service.dart';
import '../theme/theme_provider.dart';
import '../services/refresh_service.dart';


class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final int _currentIndex = 2; // Index for notification in bottom nav (0=Schedule, 1=Group, 2=Notification, 3=Profile)
  List<models.Notification> _notifications = [];
  bool _isLoading = true;
  StreamSubscription<void>? _profileRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();

    // Listen for profile changes to refresh notifications with updated user data
    _profileRefreshSubscription = RefreshService().profileChanges.listen((_) {
      if (mounted) {
        _loadNotifications();
      }
    });
  }

  @override
  void dispose() {
    _profileRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      // Get real notifications from the service
      final allNotifications = await NotificationService.getNotifications();

      // Filter out declined invitations
      final notifications = allNotifications.where((notification) {
        // Keep all non-invitation notifications
        if (notification.type != NotificationType.INVITATION) {
          return true;
        }
        // For invitation notifications, only keep pending ones
        return notification.groupInvitation?.status == InvitationStatus.PENDING;
      }).toList();

      // Sort notifications: invitations first, then by timestamp
      notifications.sort((a, b) {
        // Invitations always come first
        if (a.type == NotificationType.INVITATION && b.type != NotificationType.INVITATION) {
          return -1;
        }
        if (b.type == NotificationType.INVITATION && a.type != NotificationType.INVITATION) {
          return 1;
        }
        // If both are invitations or both are not invitations, sort by timestamp
        return b.timestamp.getDateTimeInUtc().compareTo(a.timestamp.getDateTimeInUtc());
      });

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final success = await NotificationService.deleteNotification(notificationId);
    if (success) {
      setState(() {
        _notifications.removeWhere((n) => n.id == notificationId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete notification')),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    final success = await NotificationService.markAsRead(notificationId);
    if (success) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(
            isRead: true,
          );
        }
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.grey[100];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.black),
                  SizedBox(width: 8),
                  Text(
                    'Calendar 1',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                await NotificationService.markAllAsRead();
                await _loadNotifications();
              },
              icon: const Icon(Icons.mark_email_read, size: 18),
              label: const Text('Mark All Read'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        titleSpacing: 16,
      ),
      body: RefreshController(
        onRefresh: _loadNotifications,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Text(
                    'No notifications',
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];

                    // Handle invitation notifications differently
                    if (notification.type == NotificationType.INVITATION) {
                      return _buildInvitationNotification(notification);
                    }

                    final schedule = notification.schedule;

                    // Skip if schedule is null for non-invitation notifications
                    if (schedule == null) return const SizedBox.shrink();

                    // Format the date for display (in local timezone)
                    final startDateLocal = TimezoneService.utcToLocal(schedule.startTime);
                    final day = startDateLocal.day.toString().padLeft(2, '0');
                    final month = DateFormat('MMMM').format(startDateLocal);
                    final year = startDateLocal.year.toString();

                    // Format the time for display (in local timezone)
                    final startTime = DateFormat('HH:mm').format(startDateLocal);
                    final endDateLocal = TimezoneService.utcToLocal(schedule.endTime);
                    final endTime = DateFormat('HH:mm').format(endDateLocal);

                    return Dismissible(
                      key: Key(notification.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      onDismissed: (direction) {
                        _deleteNotification(notification.id);
                      },
                      child: GestureDetector(
                        onTap: () => _markAsRead(notification.id),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: notification.isRead ? Colors.green[50] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 25),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        child: Opacity(
                          opacity: notification.isRead ? 0.7 : 1.0,
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Date column
                                Container(
                                  width: 60,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        day,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        month,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        year,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Vertical divider
                                Container(
                                  width: 1,
                                  color: Colors.grey[300],
                                ),
                                // Content column
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Time indicator with dot
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: _getNotificationColor(notification, Colors.green),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '$startTime-$endTime',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Title
                                        Text(
                                          schedule.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        const SizedBox(height: 4),
                                        // Notification message
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                NotificationService.getNotificationMessage(notification),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                            ),
                                            // Read/Unread indicator
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: notification.isRead
                                                    ? Colors.green[100]
                                                    : Colors.blue[100],
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    notification.isRead
                                                        ? Icons.check_circle
                                                        : Icons.circle,
                                                    size: 12,
                                                    color: notification.isRead
                                                        ? Colors.green[700]
                                                        : Colors.blue,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    notification.isRead ? 'Read' : 'New',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w500,
                                                      color: notification.isRead
                                                          ? Colors.green[700]
                                                          : Colors.blue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ));
                  },
                ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: _currentIndex),
    );
  }

  Widget _buildInvitationNotification(models.Notification notification) {
    final invitation = notification.groupInvitation;
    if (invitation == null) return const SizedBox.shrink();

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 24,
        ),
      ),
      onDismissed: (direction) {
        _deleteNotification(notification.id);
      },
      child: GestureDetector(
        onTap: () => _markAsRead(notification.id),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.green[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 25),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Opacity(
            opacity: notification.isRead ? 0.7 : 1.0,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon column (similar to date column in regular notifications)
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.group_add,
                          color: Colors.orange[700],
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invite',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Vertical divider
                  Container(
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  // Content column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          const Text(
                            'Group Invitation',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Invitation message
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  NotificationService.getNotificationMessage(notification),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                              // Read/Unread indicator
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: notification.isRead
                                      ? Colors.green[100]
                                      : Colors.blue[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      notification.isRead
                                          ? Icons.check_circle
                                          : Icons.circle,
                                      size: 12,
                                      color: notification.isRead
                                          ? Colors.green[700]
                                          : Colors.blue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      notification.isRead ? 'Read' : 'New',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: notification.isRead
                                            ? Colors.green[700]
                                            : Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Accept/Decline icon buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Accept button with checkmark icon
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: () => _acceptInvitation(invitation.id),
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Decline button with X icon
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: () => _declineInvitation(invitation.id),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _acceptInvitation(String invitationId) async {
    try {
      await GroupService.acceptGroupInvitation(invitationId);

      // Refresh notifications to get the latest state
      await _loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation accepted! You are now a member of the group.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept invitation: $e')),
        );
      }
    }
  }

  Future<void> _declineInvitation(String invitationId) async {
    try {
      await GroupService.declineGroupInvitation(invitationId);

      // Refresh notifications to get the latest state
      await _loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline invitation: $e')),
        );
      }
    }
  }

  Color _getNotificationColor(models.Notification notification, Color defaultColor) {
    // Colors based on notification type
    switch (notification.type) {
      case NotificationType.CREATED:
        return Colors.purple;
      case NotificationType.UPCOMING:
        return Colors.blue;
      case NotificationType.INVITATION:
        return Colors.orange;
    }
  }
}
