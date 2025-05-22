import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../models/Notification.dart' as models;
import '../models/NotificationType.dart';
import '../services/notification_service.dart';
import '../theme/theme_provider.dart';


class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final int _currentIndex = 2; // Index for notification in bottom nav (0=Schedule, 1=Group, 2=Notification, 3=Profile)
  List<models.Notification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      // Get real notifications from the service
      final notifications = await NotificationService.getNotifications();

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await NotificationService.markAsRead(notificationId);
      await _loadNotifications();
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
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
      body: _isLoading
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
                    final schedule = notification.schedule;

                    // Skip if schedule is null
                    if (schedule == null) return const SizedBox.shrink();

                    // Format the date for display
                    final startDate = schedule.startTime.getDateTimeInUtc();
                    final day = startDate.day.toString().padLeft(2, '0');
                    final month = DateFormat('MMMM').format(startDate);
                    final year = startDate.year.toString();

                    // Format the time for display
                    final startTime = DateFormat('HH:mm').format(startDate);
                    final endTime = DateFormat('HH:mm').format(
                      schedule.endTime.getDateTimeInUtc(),
                    );

                    return GestureDetector(
                      onTap: () => _markAsRead(notification.id),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: notification.isRead
                              ? Border.all(color: Colors.grey.withValues(alpha: 25), width: 1)
                              : null,
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
                                            if (notification.isRead)
                                              const Icon(
                                                Icons.check_circle_outline,
                                                size: 16,
                                                color: Colors.grey,
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
                    );
                  },
                ),
      bottomNavigationBar: BottomNavBar(currentIndex: _currentIndex),
    );
  }

  Color _getNotificationColor(models.Notification notification, Color defaultColor) {
    // Colors based on notification type
    switch (notification.type) {
      case NotificationType.CREATED:
        return Colors.purple;
      case NotificationType.UPCOMING:
        return Colors.blue;
    }
  }
}
