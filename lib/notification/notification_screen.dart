import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/refresh_controller.dart';
import '../widgets/group_selector_sidebar.dart';
import '../models/Notification.dart' as models;
import '../models/NotificationType.dart';
import '../models/InvitationStatus.dart';
import '../services/notification_service.dart';
import '../services/timezone_service.dart';
import '../dynamo/group_service.dart';
import '../theme/theme_provider.dart';
import '../providers/group_selection_provider.dart';
import '../services/refresh_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with TickerProviderStateMixin {
  final int _currentIndex =
      2; // Index for notification in bottom nav (0=Schedule, 1=Group, 2=Notification, 3=Profile)
  List<models.Notification> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  StreamSubscription<void>? _profileRefreshSubscription;
  StreamSubscription<void>? _groupRefreshSubscription;

  final int _pageSize = 2;
  String? _nextToken;
  final ScrollController _scrollController = ScrollController();

  // Sidebar state
  bool _isSidebarOpen = false;
  late AnimationController _sidebarAnimationController;
  late Animation<double> _sidebarAnimation;
  late AnimationController _navbarAnimationController;
  late Animation<double> _navbarAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize sidebar animation
    _sidebarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _sidebarAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _sidebarAnimationController,
      curve: Curves.easeInOut,
    ));

    // Initialize navbar animation
    _navbarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _navbarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _navbarAnimationController,
      curve: Curves.easeInOut,
    ));

    _loadNotifications();

    // Set up scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // Listen for profile changes to refresh notifications with updated user data
    _profileRefreshSubscription = RefreshService().profileChanges.listen((_) {
      if (mounted) {
        _loadNotifications();
      }
    });

    // Listen for group changes to refresh notifications when group membership changes
    _groupRefreshSubscription = RefreshService().groupChanges.listen((_) {
      if (mounted) {
        _loadNotifications();
      }
    });
  }

  @override
  void dispose() {
    _profileRefreshSubscription?.cancel();
    _groupRefreshSubscription?.cancel();
    _scrollController.dispose();
    _sidebarAnimationController.dispose();
    _navbarAnimationController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });

    if (_isSidebarOpen) {
      _sidebarAnimationController.forward();
      _navbarAnimationController.forward();
    } else {
      _sidebarAnimationController.reverse();
      _navbarAnimationController.reverse();
    }
  }

  void _closeSidebar() {
    if (_isSidebarOpen) {
      setState(() {
        _isSidebarOpen = false;
      });
      _sidebarAnimationController.reverse();
      _navbarAnimationController.reverse();
    }
  }

  Future<void> _markAsUnread(String notificationId) async {
    // Anggap saja NotificationService punya fungsi ini, yang perlu Anda buat di service-nya
    final success = await NotificationService.markAsUnread(notificationId);
    if (success) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(
            isRead: false, // <-- Diubah menjadi false (belum dibaca)
          );
          // Panggil _sortNotifications() agar posisinya pindah ke atas lagi
          _sortNotifications();
        }
      });
    }
  }

// Tambahkan juga fungsi ini di dalam _NotificationScreenState
  Future<void> _toggleReadStatus(models.Notification notification) async {
    if (notification.isRead) {
      // Jika SUDAH dibaca, panggil fungsi untuk menjadikannya BELUM dibaca
      await _markAsUnread(notification.id);
    } else {
      // Jika BELUM dibaca, panggil fungsi untuk menjadikannya SUDAH dibaca
      await _markAsRead(notification.id);
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final groupProvider =
          Provider.of<GroupSelectionProvider>(context, listen: false);

      // Get notifications based on group selection
      List<models.Notification> allNotifications;
      if (groupProvider.isPersonalMode) {
        // Load all notifications for personal mode
        allNotifications = await NotificationService.getNotifications();
      } else if (groupProvider.selectedGroup != null) {
        // Load notifications for specific group
        allNotifications = await NotificationService.getNotificationsForGroup(
            groupProvider.selectedGroup!.id);
      } else {
        // No group selected, load all notifications
        allNotifications = await NotificationService.getNotifications();
      }

      // Filter out declined invitations
      final notifications = allNotifications.where((notification) {
        // Keep all non-invitation notifications
        if (notification.type != NotificationType.INVITATION) {
          return true;
        }
        // For invitation notifications, only keep pending ones
        return notification.groupInvitation?.status == InvitationStatus.PENDING;
      }).toList();

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });

      // Sort notifications using the centralized sorting method
      _sortNotifications();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final success =
        await NotificationService.deleteNotification(notificationId);
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
          // Re-sort notifications after marking as read to maintain proper order
          _sortNotifications();
        }
      });
    }
  }

  /// Extract event date from notification for sorting purposes
  DateTime? _getEventDate(models.Notification notification) {
    // For schedule-related notifications, use the schedule's start time
    if (notification.schedule != null) {
      return notification.schedule!.startTime.getDateTimeInUtc();
    }

    // For invitation notifications, use the notification timestamp as fallback
    // since invitations don't have associated schedule dates
    if (notification.type == NotificationType.INVITATION) {
      return notification.timestamp.getDateTimeInUtc();
    }

    // Fallback to notification timestamp
    return notification.timestamp.getDateTimeInUtc();
  }

  /// Sort notifications with read/unread hierarchy and chronological order
  void _sortNotifications() {
    _notifications.sort((a, b) {
      // First priority: unread notifications come before read notifications
      if (!a.isRead && b.isRead) return -1;
      if (a.isRead && !b.isRead) return 1;

      // Second priority: invitations come first within each read/unread group
      if (a.type == NotificationType.INVITATION &&
          b.type != NotificationType.INVITATION) {
        return -1;
      }
      if (b.type == NotificationType.INVITATION &&
          a.type != NotificationType.INVITATION) {
        return 1;
      }

      // Third priority: different sorting logic for read vs unread notifications
      if (a.isRead && b.isRead) {
        // For read notifications: sort by notification timestamp (most recent notifications first)
        return b.timestamp
            .getDateTimeInUtc()
            .compareTo(a.timestamp.getDateTimeInUtc());
      } else {
        // For unread notifications: sort by event/schedule date (upcoming events first)
        DateTime? aEventDate = _getEventDate(a);
        DateTime? bEventDate = _getEventDate(b);

        // If both have event dates, compare them
        if (aEventDate != null && bEventDate != null) {
          return bEventDate.compareTo(aEventDate); // Most recent events first
        }

        // If only one has an event date, prioritize it
        if (aEventDate != null && bEventDate == null) return -1;
        if (bEventDate != null && aEventDate == null) return 1;

        // Fallback: sort by notification timestamp (most recent first)
        return b.timestamp
            .getDateTimeInUtc()
            .compareTo(a.timestamp.getDateTimeInUtc());
      }
    });
  }

  /// Handle scroll events for pagination
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more notifications when user is near the bottom
      _loadMoreNotifications();
    }
  }

  /// Load more notifications for pagination
  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || _nextToken == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final groupProvider =
          Provider.of<GroupSelectionProvider>(context, listen: false);

      // Get more notifications based on group selection
      List<models.Notification> moreNotifications;
      if (groupProvider.isPersonalMode) {
        // Load more notifications for personal mode
        moreNotifications = await NotificationService.getNotifications();
      } else if (groupProvider.selectedGroup != null) {
        // Load more notifications for specific group
        moreNotifications = await NotificationService.getNotificationsForGroup(
            groupProvider.selectedGroup!.id);
      } else {
        // No group selected, load more notifications
        moreNotifications = await NotificationService.getNotifications();
      }

      // Filter out declined invitations
      final filteredNotifications = moreNotifications.where((notification) {
        // Keep all non-invitation notifications
        if (notification.type != NotificationType.INVITATION) {
          return true;
        }
        // For invitation notifications, only keep pending ones
        return notification.groupInvitation?.status == InvitationStatus.PENDING;
      }).toList();

      setState(() {
        _notifications.addAll(filteredNotifications);
        _isLoadingMore = false;
      });

      // Sort notifications after adding new ones
      _sortNotifications();
    } catch (e) {
      debugPrint('Error loading more notifications: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final groupProvider = Provider.of<GroupSelectionProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final backgroundColor =
        isDarkMode ? const Color(0xFF121212) : Colors.grey[100];

    return Scaffold(
      extendBody: true,
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Main content
          GestureDetector(
            onTap: _closeSidebar,
            child: Column(
              children: [
                // Custom app bar
                Container(
                  color: backgroundColor,
                  padding: const EdgeInsets.only(
                      top: 56, left: 16, right: 16, bottom: 8),
                  child: Row(
                    children: [
                      // Group selector button
                      // DIUBAH: Menggunakan SizedBox untuk ukuran yang pasti
                      SizedBox(
                        width: 148.0, // ukuran fix
                        height: 50.0,
                        // DIUBAH: Menggunakan InkWell untuk efek splash
                        child: InkWell(
                          onTap: _toggleSidebar,
                          borderRadius: BorderRadius.circular(
                              30), // Samakan dengan radius Container
                          child: Container(
                            // DIUBAH: Padding disesuaikan
                            padding:
                                const EdgeInsets.only(left: 17.0, right: 17.0),
                            // DIUBAH: Dekorasi disamakan
                            decoration: BoxDecoration(
                              color:
                                  isDarkMode ? Colors.grey[800] : Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withAlpha((0.1 * 255).round()),
                                  offset: const Offset(0, 4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              // mainAxisSize tidak lagi diperlukan karena ukuran diatur oleh SizedBox
                              children: [
                                // DIUBAH: Ikon menggunakan SvgPicture
                                SvgPicture.asset(
                                  'assets/icons/calendar_selector-icon.svg',
                                  width: 24,
                                  height: 24,
                                ),
                                // DIUBAH: Spasi disesuaikan
                                const SizedBox(width: 9),
                                // DIUBAH: Teks dibungkus Flexible agar tidak overflow
                                Flexible(
                                  child: Text(
                                    groupProvider.currentSelectionName,
                                    // DIUBAH: TextStyle disamakan sepenuhnya
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF222B45),
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.normal,
                                      fontSize: 14,
                                      fontFamily: 'Arial',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          // TODO: Tambahkan logika untuk "mark all read" di sini
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/icons/mark_email_unread-icon.svg',
                              width: 22,
                              height: 22,
                              colorFilter: ColorFilter.mode(
                                isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF222B45),
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Teks "Mark all read"
                            Text(
                              'Mark all read',
                              // Menerapkan gaya teks yang Anda minta
                              style: TextStyle(
                                fontStyle: FontStyle.normal,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                                // Warna teks juga disesuaikan untuk dark mode
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF222B45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Main content
                Expanded(
                  child: RefreshController(
                    onRefresh: _loadNotifications,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _notifications.isEmpty
                            ? Center(
                                child: Text(
                                  'No notifications',
                                  style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: _notifications.length +
                                    (_isLoadingMore ? 1 : 0),
                                padding: const EdgeInsets.only(
                                    top: 8, bottom: 125.0),
                                itemBuilder: (context, index) {
                                  if (index == _notifications.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    );
                                  }
                                  final notification = _notifications[index];

                                  // Handle invitation notifications differently
                                  if (notification.type ==
                                      NotificationType.INVITATION) {
                                    return _buildInvitationNotification(
                                        notification);
                                  }

                                  final schedule = notification.schedule;

                                  // Skip if schedule is null for non-invitation notifications
                                  if (schedule == null) {
                                    return const SizedBox.shrink();
                                  }
                                  // Format the date for display (in local timezone)
                                  final startDateLocal =
                                      TimezoneService.utcToLocal(
                                          schedule.startTime);
                                  final day = DateFormat('dd').format(
                                      startDateLocal); // Format to always have two digits
                                  final month =
                                      DateFormat('MMMM').format(startDateLocal);
                                  final year = startDateLocal.year.toString();

                                  // Format the time for display (in local timezone)
                                  final startTime = DateFormat('HH:mm')
                                      .format(startDateLocal);
                                  final endDateLocal =
                                      TimezoneService.utcToLocal(
                                          schedule.endTime);
                                  final endTime =
                                      DateFormat('HH:mm').format(endDateLocal);

                                  // Determine notification color based on isRead status or other logic
                                  final bool isRead = notification
                                      .isRead; // You might have this logic already
                                  final cardColor = isDarkMode
                                      ? (isRead
                                          ? Colors.grey[850]
                                          : const Color(0xFF1E1E1E))
                                      : (isRead
                                          ? Colors.grey[200]
                                          : Colors.white);
                                  final dotColor = _getNotificationColor(
                                      notification,
                                      Colors
                                          .green); // Using your existing function for the dot color

                                  return Dismissible(
                                    key: Key(notification.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
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
                                      onTap: () =>
                                          _toggleReadStatus(notification),
                                      child: Opacity(
                                        opacity: isRead ? 0.6 : 1.0,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: cardColor,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.05),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: IntrinsicHeight(
                                            child: Row(
                                              children: [
                                                // Kolom Tanggal (Kiri)
                                                SizedBox(
                                                  width:
                                                      70, // Beri lebar tetap agar rapi
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(
                                                        14.0, 11, 0, 11),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          day,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 34,
                                                            color: Color(
                                                                0xFF222B45),
                                                            fontStyle: FontStyle
                                                                .normal,
                                                            height: 1,
                                                          ),
                                                        ),
                                                        Text(
                                                          month,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 15,
                                                            color: Color(
                                                                0xFF222B45),
                                                            fontStyle: FontStyle
                                                                .normal,
                                                          ),
                                                        ),
                                                        Text(
                                                          year,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 10,
                                                            color: Color(
                                                                0xFF8F9BB3),
                                                            fontStyle: FontStyle
                                                                .normal,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 14.0),
                                                Container(
                                                  width: 1,
                                                  color: isDarkMode
                                                      ? Colors.grey[700]
                                                      : Colors.grey[300],
                                                ),

                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 12.0,
                                                        horizontal: 12.0),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Container(
                                                              width: 8,
                                                              height: 8,
                                                              decoration:
                                                                  BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                color: Colors
                                                                    .transparent,
                                                                border:
                                                                    Border.all(
                                                                  color:
                                                                      dotColor,
                                                                  width: 2.5,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 5),
                                                            Text(
                                                              '$startTime-$endTime',
                                                              style:
                                                                  const TextStyle(
                                                                fontStyle:
                                                                    FontStyle
                                                                        .normal,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                fontSize: 13,
                                                                color: Color(
                                                                    0xFF8F9BB3),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 1,
                                                        ),
                                                        // Judul Acara
                                                        Text(
                                                          schedule.title,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 18,
                                                            color: Color(
                                                                0xFF222B45),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(
                                                          height: 1,
                                                        ),

                                                        Text(
                                                          NotificationService
                                                              .getNotificationMessage(
                                                                  notification),
                                                          style:
                                                              const TextStyle(
                                                            fontStyle: FontStyle
                                                                .normal,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            fontSize: 13,
                                                            color: Color(
                                                                0xFF8F9BB3),
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
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
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),

          // Sidebar overlay
          if (_isSidebarOpen)
            GestureDetector(
              onTap: _closeSidebar,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),

          // Animated sidebar
          AnimatedBuilder(
            animation: _sidebarAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_sidebarAnimation.value * 320, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GroupSelectorSidebar(
                    groups: groupProvider.groups,
                    selectedGroup: groupProvider.selectedGroup,
                    isPersonalMode: groupProvider.isPersonalMode,
                    showPersonalOption: true,
                    showCreateGroupButton: false,
                    onGroupSelected: (group) {
                      groupProvider.selectGroup(group);
                      _closeSidebar();
                      _loadNotifications();
                    },
                    onPersonalModeSelected: () {
                      groupProvider.selectPersonalMode();
                      _closeSidebar();
                      _loadNotifications();
                    },
                    onCreateGroup: () {
                      // This won't be called since showCreateGroupButton is false
                    },
                    currentUserId: groupProvider.currentUserId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: AnimatedBottomNavBar(
        currentIndex: _currentIndex,
        navbarAnimation: _navbarAnimation,
      ),
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
                                  NotificationService.getNotificationMessage(
                                      notification),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
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
                                  onPressed: () =>
                                      _acceptInvitation(invitation.id),
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
                                  onPressed: () =>
                                      _declineInvitation(invitation.id),
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
      // Get the group provider before any async calls
      final groupProvider =
          Provider.of<GroupSelectionProvider>(context, listen: false);

      await GroupService.acceptGroupInvitation(invitationId);

      // Refresh the group provider to immediately show the new group in the sidebar
      await groupProvider.refreshGroups();

      // Refresh notifications to get the latest state
      await _loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Invitation accepted! You are now a member of the group.')),
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

  Color _getNotificationColor(
      models.Notification notification, Color defaultColor) {
    if (notification.schedule?.color != null &&
        notification.schedule!.color!.isNotEmpty) {
      try {
        String colorString = notification.schedule!.color!;
        int colorValue;

        if (colorString.startsWith('#')) {
          colorValue = int.parse(colorString.substring(1), radix: 16);
          if (colorString.length == 7) {
            colorValue = 0xFF000000 | colorValue;
          }
        } else {
          colorValue = int.parse(colorString);
        }

        final scheduleColor = Color(colorValue);
        return scheduleColor;
      } catch (e) {
        debugPrint(
            '❌ Failed to parse notification schedule color: ${notification.schedule!.color}, error: $e');
      }
    } else {
      debugPrint(
          '⚠️ No schedule color available for notification ${notification.id}, using fallback');
    }

    // Fallback: colors based on notification type
    Color fallbackColor;
    switch (notification.type) {
      case NotificationType.CREATED:
        fallbackColor = Colors.purple;
        break;
      case NotificationType.UPCOMING:
        fallbackColor = Colors.blue;
        break;
      case NotificationType.INVITATION:
        fallbackColor = Colors.orange;
        break;
    }
    return fallbackColor;
  }
}
