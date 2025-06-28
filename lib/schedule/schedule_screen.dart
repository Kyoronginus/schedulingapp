import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';
import 'dart:async';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/refresh_controller.dart';
import '../widgets/group_selector_sidebar.dart';
import '../models/Schedule.dart';
import 'schedule_service.dart';
import '../theme/theme_provider.dart';
import '../providers/group_selection_provider.dart';
import '../utils/utils_functions.dart';
import '../services/timezone_service.dart';
import '../services/refresh_service.dart';
import '../widgets/smart_back_button.dart';
import 'create_schedule/schedule_form_dialog.dart';
import 'schedule_conflict_detector.dart';
import '../dynamo/group_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Data class to represent a conflict availability notice
class ConflictAvailabilityNotice {
  final Schedule conflictingSchedule;
  final TemporalDateTime startTime;
  final TemporalDateTime endTime;
  final String? username;

  ConflictAvailabilityNotice({
    required this.conflictingSchedule,
    required this.startTime,
    required this.endTime,
    this.username,
  });
}

// Extension to make any widget tappable
extension TapExtension on Widget {
  Widget onTap(VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: this);
  }
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with TickerProviderStateMixin, NavigationMemoryMixin {
  final int _currentIndex = 0; // Schedule is the 1st tab (index 0)
  bool _isLoading = true;
  Map<DateTime, List<Schedule>> _groupedSchedules = {};
  Map<DateTime, Set<String>> _conflictsByDate = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _currentMonth = DateFormat('MMMM').format(DateTime.now());
  int _currentYear = DateTime.now().year;
  final Map<String, bool> _isAdminCache =
      {}; // Cache to store admin status for groups
  // bool _showCreateForm = false; // Flag to show/hide the create form overlay

  // Sidebar state
  bool _isSidebarOpen = false;
  late AnimationController _sidebarAnimationController;
  late Animation<double> _sidebarAnimation;
  late AnimationController _navbarAnimationController;
  late Animation<double> _navbarAnimation;

  // Refresh service subscriptions
  StreamSubscription<void>? _scheduleRefreshSubscription;
  StreamSubscription<void>? _groupRefreshSubscription;
  StreamSubscription<void>? _profileRefreshSubscription;

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

    // Load initial data
    _loadSchedules();

    // Listen for refresh notifications
    _scheduleRefreshSubscription = RefreshService().scheduleChanges.listen((_) {
      if (mounted) {
        _loadSchedules();
      }
    });

    _groupRefreshSubscription = RefreshService().groupChanges.listen((_) {
      if (mounted) {
        _loadSchedules(); // Reload schedules when groups change
      }
    });

    // Listen for profile changes to refresh user-related data
    _profileRefreshSubscription = RefreshService().profileChanges.listen((_) {
      if (mounted) {
        _loadSchedules(); // Reload schedules to get updated user data
      }
    });
  }

  @override
  void dispose() {
    _scheduleRefreshSubscription?.cancel();
    _groupRefreshSubscription?.cancel();
    _profileRefreshSubscription?.cancel();
    _sidebarAnimationController.dispose();
    _navbarAnimationController.dispose();
    super.dispose();
  }

  Future<bool> _isUserAdmin(String groupId) async {
    // Check cache first
    if (_isAdminCache.containsKey(groupId)) {
      return _isAdminCache[groupId]!;
    }

    final groupProvider =
        Provider.of<GroupSelectionProvider>(context, listen: false);
    final currentUserId = groupProvider.currentUserId;

    if (currentUserId == null) {
      return false;
    }

    try {
      // Query to check if the current user is an admin of the group
      final request = GraphQLRequest<String>(
        document: '''
          query GetGroupUserRole(\$userId: ID!, \$groupId: ID!) {
            listGroupUsers(filter: {
              and: {
                userId: {eq: \$userId},
                groupId: {eq: \$groupId}
              }
            }) {
              items {
                isAdmin
              }
            }
          }
        ''',
        variables: {'userId': currentUserId, 'groupId': groupId},
      );

      final response = await Amplify.API.query(request: request).response;
      final data = jsonDecode(response.data ?? '{}');
      final items = data['listGroupUsers']?['items'] ?? [];

      bool isAdmin = false;
      if (items.isNotEmpty) {
        isAdmin = items[0]['isAdmin'] ?? false;
      }

      // Cache the result
      _isAdminCache[groupId] = isAdmin;
      return isAdmin;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  Future<void> _loadSchedules() async {
    // Check if widget is still mounted before calling setState
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final groupProvider =
          Provider.of<GroupSelectionProvider>(context, listen: false);

      // Always load all schedules for conflict detection
      final allSchedules = await ScheduleService.loadAllSchedules();

      List<Schedule> displaySchedules = [];
      if (groupProvider.isPersonalMode) {
        // In personal mode, display all schedules
        displaySchedules = allSchedules;
      } else if (groupProvider.selectedGroup != null) {
        // In group mode, display schedules for the selected group
        displaySchedules = allSchedules
            .where((schedule) =>
                schedule.group?.id == groupProvider.selectedGroup!.id)
            .toList();
      }

      // Detect conflicts using ALL schedules for accurate conflict detection
      final allGroupedSchedules = _groupSchedulesByDate(allSchedules);
      final conflicts =
          ScheduleConflictDetector.detectAllConflicts(allGroupedSchedules);

      // Check if widget is still mounted before calling setState
      if (!mounted) return;
      setState(() {
        _allSchedules =
            allSchedules; // Store all schedules for conflict detection
        _groupedSchedules = _groupSchedulesByDate(displaySchedules);
        _conflictsByDate = conflicts;

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load schedules: $e')));
      }

      // Check if widget is still mounted before calling setState
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Map<DateTime, List<Schedule>> _groupSchedulesByDate(
    List<Schedule> schedules,
  ) {
    final Map<DateTime, List<Schedule>> grouped = {};
    for (final schedule in schedules) {
      // Use local timezone for date grouping
      final localStartTime = TimezoneService.utcToLocal(schedule.startTime);
      final date = DateTime.utc(
        localStartTime.year,
        localStartTime.month,
        localStartTime.day,
      );
      if (grouped[date] == null) {
        grouped[date] = [];
      }
      grouped[date]!.add(schedule);
    }
    return grouped;
  }

  List<Schedule> _getSchedulesForDay(DateTime day) {
    // Normalize the date to match our grouping keys
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _groupedSchedules[normalizedDay] ?? [];
  }

  void _showCreateScheduleDialog() {
    final groupProvider =
        Provider.of<GroupSelectionProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => ScheduleFormDialog(
        onFormClosed: _loadSchedules, // Refresh jadwal setelah form ditutup
        selectedDate: _selectedDay ?? DateTime.now(),
        initialGroup:
            groupProvider.isPersonalMode ? null : groupProvider.selectedGroup,
      ),
    );
  }

  // Removed unused method _navigateToAddGroup

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDarkMode = themeProvider.isDarkMode;
        final primaryColor =
            isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF4A80F0);

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor:
                  isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              titlePadding: const EdgeInsets.all(0),
              contentPadding: const EdgeInsets.all(0),
              title: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Create New Group',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 400, // Limit maximum height to prevent overflow
                  maxWidth: 400, // Limit maximum width for better layout
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            labelText: 'Group Name',
                            labelStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.grey[300]
                                    : Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: isDarkMode
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            labelText: 'Description (Optional)',
                            labelStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.grey[300]
                                    : Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: isDarkMode
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                SizedBox(
                  width: 100,
                  child: TextButton(
                    onPressed:
                        isSaving ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Group name is required')),
                              );
                              return;
                            }

                            setState(() => isSaving = true);

                            final navigator = Navigator.of(context);
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            final groupProvider =
                                Provider.of<GroupSelectionProvider>(context,
                                    listen: false);

                            try {
                              await GroupService.createGroup(
                                name: name,
                                description: descriptionController.text.trim(),
                              );

                              if (mounted) {
                                // Refresh the groups from provider first
                                await groupProvider.refreshGroups();

                                navigator.pop();
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Group created successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Failed to create group: ${e.toString()}')),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => isSaving = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Create'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateMonthYear(int month, int year) {
    setState(() {
      _focusedDay = DateTime(year, month, 1);
      _currentMonth = DateFormat('MMMM').format(DateTime(year, month, 1));
      _currentYear = year;
    });
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

  void _showScheduleDetailDialog(BuildContext context, Schedule schedule) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final activeColor =
        isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF735BF2);
    final dotColor = _getDotColor(schedule, activeColor, 0);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          title: null,
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: dotColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      width: double.infinity,
                      child: Text(
                        schedule.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    Container(
                      color:
                          isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                      padding: const EdgeInsets.all(24.0),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                              dialogContext,
                              iconAsset:
                                  'assets/icons/calendar_navbar-icon.svg',
                              title: 'Date',
                              content: DateFormat('EEEE, dd MMMM yy').format(
                                  TimezoneService.utcToLocal(
                                      schedule.startTime)),
                            ),
                            _buildDetailRow(
                              dialogContext,
                              iconAsset: 'assets/icons/clock-icon.svg',
                              title: 'Time',
                              content:
                                  '${_formatTime(TimezoneService.utcToLocal(schedule.startTime))} - ${_formatTime(TimezoneService.utcToLocal(schedule.endTime))}',
                            ),
                            if (schedule.location != null &&
                                schedule.location!.isNotEmpty)
                              _buildDetailRow(
                                dialogContext,
                                iconAsset: 'assets/icons/pin_location-icon.svg',
                                title: 'Location',
                                content: schedule.location,
                                isLink: true,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(dialogContext),
                  tooltip: 'Close',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String iconAsset,
    required String title,
    required String? content,
    bool isLink = false,
  }) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subTextColor =
        Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    final primaryColor = Theme.of(context).primaryColor;

    if (content == null || content.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(color: subTextColor, fontSize: 14)),
                const SizedBox(height: 4),
                isLink
                    ? InkWell(
                        onTap: () async {
                          final query = Uri.encodeComponent(content);
                          final uri = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=$query');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Text(
                          content,
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                    : Text(
                        content,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final groupProvider = Provider.of<GroupSelectionProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final activeColor = isDarkMode ? const Color(0xFF4CAF50) : primaryColor;

    return NavigationMemoryWrapper(
      currentRoute: '/schedule',
      child: Scaffold(
        extendBody: true,
        backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF1F1F1),
        body: RefreshController(
          onRefresh: _loadSchedules,
          child: Stack(
            children: [
              // Main content
              GestureDetector(
                onTap: _closeSidebar,
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: isDarkMode
                              ? const Color(0xFF4CAF50)
                              : primaryColor,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSchedules,
                        color:
                            isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top: 42.0, left: 16.0, right: 16.0),
                          child: Column(
                            children: [
                              // Top row with calendar selector and month/year selector
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                  vertical: 10.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildCalendarSelector(),
                                    const SizedBox(width: 20),
                                    _buildMonthYearSelector(),
                                  ],
                                ),
                              ),

                              // Calendar
                              Container(
                                margin: const EdgeInsets.only(top: 16.0),
                                padding: const EdgeInsets.fromLTRB(
                                    8.0, 12.0, 8.0, 8.0),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color(0xFF2A2A2A)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                child: TableCalendar(
                                  firstDay: DateTime.utc(2000, 1, 1),
                                  lastDay: DateTime.utc(2100, 12, 31),
                                  focusedDay: _focusedDay,
                                  selectedDayPredicate: (day) =>
                                      isSameDay(_selectedDay, day),
                                  eventLoader: _getSchedulesForDay,
                                  onDaySelected: (selectedDay, focusedDay) {
                                    setState(() {
                                      _selectedDay = selectedDay;
                                      _focusedDay = focusedDay;
                                    });
                                  },
                                  onPageChanged: (focusedDay) {
                                    setState(() {
                                      _focusedDay = focusedDay;
                                      _currentMonth =
                                          DateFormat('MMMM').format(focusedDay);
                                      _currentYear = focusedDay.year;
                                    });
                                  },
                                  startingDayOfWeek: StartingDayOfWeek
                                      .monday, // Start with Monday
                                  daysOfWeekHeight: 30.0,
                                  daysOfWeekStyle: DaysOfWeekStyle(
                                    weekdayStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF0F140F),
                                    ),
                                    weekendStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF0F140F),
                                    ),
                                  ),
                                  weekendDays: const [DateTime.sunday],
                                  rowHeight: 45.0,
                                  calendarStyle: CalendarStyle(
                                    cellMargin: const EdgeInsets.all(4.0),

                                    todayDecoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),

                                    selectedDecoration: BoxDecoration(
                                      color: activeColor,
                                      shape: BoxShape.circle,
                                    ),

                                    // Only make Sunday red (last day of week when starting with Monday)
                                    weekendTextStyle: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 18,
                                    ),

                                    outsideTextStyle: TextStyle(
                                        color: isDarkMode
                                            ? Colors.grey.shade600
                                            : const Color(0xFF8F9BB3),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500),

                                    defaultTextStyle: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 18,
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF252525),
                                    ),

                                    selectedTextStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),

                                    todayTextStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: activeColor,
                                    ),
                                  ),
                                  headerVisible: false,

                                  calendarBuilders: CalendarBuilders(
                                    markerBuilder: (context, date, events) {
                                      final scheduleEvents =
                                          events.cast<Schedule>();
                                      if (scheduleEvents.isEmpty) {
                                        return null;
                                      }

                                      // Check if there are conflicts on this date
                                      final groupProvider =
                                          Provider.of<GroupSelectionProvider>(
                                              context,
                                              listen: false);
                                      bool hasConflict = false;

                                      // Normalize the date to match our conflict detection keys
                                      final normalizedDate = DateTime.utc(
                                          date.year, date.month, date.day);

                                      // Only show conflicts in group mode, not in personal mode
                                      if (!groupProvider.isPersonalMode) {
                                        // In group mode, show conflicts only for the selected group
                                        final currentGroupId =
                                            groupProvider.selectedGroup?.id;
                                        hasConflict = currentGroupId != null &&
                                            ScheduleConflictDetector
                                                .groupHasConflictOnDate(
                                                    currentGroupId,
                                                    normalizedDate,
                                                    _conflictsByDate);
                                      }

                                      final uniqueColors = <Color>{};
                                      for (var schedule in scheduleEvents) {
                                        final color = _getDotColor(schedule,
                                            activeColor, uniqueColors.length);
                                        uniqueColors.add(color);
                                      }

                                      // Limit to 3 normal dots if there's a conflict, otherwise 4
                                      final maxDots = hasConflict ? 3 : 4;
                                      final dots = <Widget>[];

                                      // Add normal schedule dots
                                      dots.addAll(
                                        uniqueColors
                                            .take(maxDots)
                                            .map((color) => Container(
                                                  width: 6,
                                                  height: 6,
                                                  margin: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 1.5),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.transparent,
                                                    border: Border.all(
                                                      color: color,
                                                      width: 1.75,
                                                    ),
                                                  ),
                                                ))
                                            .toList(),
                                      );

                                      // Add conflict icon if there's a conflict
                                      if (hasConflict) {
                                        dots.add(
                                          Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 1.5),
                                            child: SvgPicture.asset(
                                              'assets/icons/x-icon.svg',
                                              width: 6,
                                              height: 6,
                                            ),
                                          ),
                                        );
                                      }

                                      return Positioned(
                                        bottom: -4,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: dots,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // Schedule list
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20.0),
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              Expanded(child: _buildScheduleList()),
                            ],
                          ),
                        ),
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
                        showCreateGroupButton: true,
                        onGroupSelected: (group) {
                          groupProvider.selectGroup(group);
                          _closeSidebar();
                          _loadSchedules();
                        },
                        onPersonalModeSelected: () {
                          groupProvider.selectPersonalMode();
                          _closeSidebar();
                          _loadSchedules();
                        },
                        onCreateGroup: () {
                          _closeSidebar();
                          _showCreateGroupDialog();
                        },
                        currentUserId: groupProvider.currentUserId,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        floatingActionButton: !groupProvider.isPersonalMode
            ? FloatingActionButton(
                onPressed: _showCreateScheduleDialog,
                backgroundColor:
                    isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                child: SvgPicture.asset(
                  'assets/icons/plus-icon.svg',
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  width: 22,
                  height: 22,
                ),
              )
            : null,
        bottomNavigationBar: AnimatedBottomNavBar(
          currentIndex: _currentIndex,
          navbarAnimation: _navbarAnimation,
        ),
      ),
    );
  }

  Widget _buildMonthYearSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    const primaryColor = Color(0xFF735BF2);
    final activeColor = isDarkMode ? const Color(0xFF4CAF50) : primaryColor;

    return Center(
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              int displayYear = _currentYear;
              final months = [
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'May',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Oct',
                'Nov',
                'Dec'
              ];
              final now = DateTime.now();

              return StatefulBuilder(
                builder: (context, setState) {
                  return AlertDialog(
                    backgroundColor:
                        isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.all(16),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon:
                                    Icon(Icons.chevron_left, color: textColor),
                                onPressed: () {
                                  setState(() => displayYear--);
                                },
                              ),
                              Text(
                                '$displayYear',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              IconButton(
                                icon:
                                    Icon(Icons.chevron_right, color: textColor),
                                onPressed: () {
                                  setState(() => displayYear++);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 1.8,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                            itemCount: 12,
                            itemBuilder: (context, index) {
                              final monthIndex = index + 1;
                              final monthName = months[index];

                              final bool isSelected =
                                  displayYear == _currentYear &&
                                      monthIndex ==
                                          DateFormat('MMMM')
                                              .parse(_currentMonth)
                                              .month;

                              // BARU: Cek apakah ini bulan dan tahun saat ini
                              final bool isCurrentMonth =
                                  displayYear == now.year &&
                                      monthIndex == now.month;

                              return InkWell(
                                onTap: () {
                                  _updateMonthYear(monthIndex, displayYear);
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected ? activeColor : null,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.transparent
                                          : isCurrentMonth
                                              ? activeColor
                                              : (isDarkMode
                                                  ? Colors.grey[700]!
                                                  : Colors.grey[300]!),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    monthName,
                                    style: TextStyle(
                                      fontWeight: isSelected || isCurrentMonth
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color:
                                          isSelected ? Colors.white : textColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        child: Container(
          width: 172,
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.1 * 255).round()),
                offset: const Offset(0, 4),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/icons/month_year_selector-icon.svg',
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentMonth,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF222B45),
                    ),
                  ),
                  Text(
                    '$_currentYear',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? Colors.grey[400]
                          : const Color(0xFF8F9BB3),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.arrow_drop_down, color: textColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0F1A2A);
    final subTextColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardBackgroundColor =
        isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
    const primaryColor = Color(0xFF735BF2);
    final activeColor = isDarkMode ? const Color(0xFF4CAF50) : primaryColor;

    final day = _selectedDay ?? _focusedDay;
    final schedules = _getSchedulesForDay(day);
    final conflictNotices = _getConflictNoticesForDay(day);

    schedules.sort(
      (a, b) => TimezoneService.utcToLocal(a.startTime).compareTo(
        TimezoneService.utcToLocal(b.startTime),
      ),
    );

    final totalItems = schedules.length + conflictNotices.length;

    if (totalItems == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No Schedule For Today.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: totalItems,
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 125.0),
      itemBuilder: (context, index) {
        if (index < schedules.length) {
          final schedule = schedules.elementAt(index);
          final dotColor = _getDotColor(schedule, activeColor, 0);

          return GestureDetector(
            onTap: () {
              _showScheduleDetailDialog(context, schedule);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              decoration: BoxDecoration(
                color: cardBackgroundColor,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    spreadRadius: 3,
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 18.0, 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                            border: Border.all(
                              color: dotColor,
                              width: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatTime(TimezoneService.utcToLocal(schedule.startTime))} - ${_formatTime(TimezoneService.utcToLocal(schedule.endTime))}',
                          style: TextStyle(
                            fontStyle: FontStyle.normal,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.0,
                            color: subTextColor,
                          ),
                        ),
                        const Spacer(),
                        FutureBuilder<bool>(
                          future: schedule.group != null
                              ? _isUserAdmin(schedule.group!.id)
                              : Future.value(true),
                          builder: (context, snapshot) {
                            final isAdmin = snapshot.data ?? false;
                            return isAdmin
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: PopupMenuButton<String>(
                                      elevation: 16.0,

                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            12.0), // Membuat sudut lebih melengkung
                                      ),
                                      offset: const Offset(0,
                                          16.0), 

                                      color: isDarkMode
                                          ? const Color(0xFF3A3A3A)
                                          : Colors.white,
                                      tooltip: 'More options',
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        Icons.more_horiz,
                                        color: subTextColor,
                                        size: 24,
                                      ),
                                      onSelected: (String value) {
                                        if (value == 'edit') {
                                          _showEditScheduleForm(schedule);
                                        } else if (value == 'delete') {
                                          _showDeleteConfirmation(schedule);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) {
                                        final editIconColor = isDarkMode
                                            ? Colors.white70
                                            : Colors.black87;
                                        return <PopupMenuEntry<String>>[
                                          PopupMenuItem<String>(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/icons/edit-icon.svg',
                                                  width: 20,
                                                  height: 20,
                                                  colorFilter: ColorFilter.mode(
                                                    editIconColor,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                const Text('Edit Schedule'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/icons/delete-icon.svg',
                                                  width: 20,
                                                  height: 20,
                                                  colorFilter:
                                                      const ColorFilter.mode(
                                                    Colors.red,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                const Text(
                                                  'Delete Schedule',
                                                  style: TextStyle(
                                                      color: Colors.red),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ];
                                      },
                                    ),
                                  )
                                : const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                    Text(
                      schedule.title,
                      style: TextStyle(
                        fontStyle: FontStyle.normal,
                        fontWeight: FontWeight.w600,
                        fontSize: 17.0,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (schedule.description != null &&
                        schedule.description!.isNotEmpty)
                      Text(
                        schedule.description!,
                        style: TextStyle(
                          fontStyle: FontStyle.normal,
                          fontWeight: FontWeight.w400,
                          fontSize: 14.0,
                          color: subTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          );
        } else {
          final noticeIndex = index - schedules.length;
          final notice = conflictNotices.elementAt(noticeIndex);
          return _buildConflictNoticeWidget(
              notice, cardBackgroundColor, textColor, subTextColor);
        }
      },
    );
  }

  // Helper method to build conflict availability notice widget
  Widget _buildConflictNoticeWidget(
    ConflictAvailabilityNotice notice,
    Color cardBackgroundColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 18.0, 10.0),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Use x-icon instead of circular dot
              SvgPicture.asset(
                'assets/icons/x-icon.svg',
                width: 12,
                height: 12,
                colorFilter: const ColorFilter.mode(
                  Colors.red,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatTime(TimezoneService.utcToLocal(notice.startTime))} - ${_formatTime(TimezoneService.utcToLocal(notice.endTime))}',
                style: const TextStyle(
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.0,
                  color: Color(0xFF8F9BB3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FutureBuilder<String>(
            future: _getUsernameFromSchedule(notice.conflictingSchedule),
            builder: (context, snapshot) {
              final username = snapshot.data ?? 'Someone';
              return Text(
                '$username is not available at these times.',
                style: TextStyle(
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.w600,
                  fontSize: 17.0,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper method to get username from schedule
  Future<String> _getUsernameFromSchedule(Schedule schedule) async {
    try {
      if (schedule.user != null && schedule.user!.name.isNotEmpty) {
        return schedule.user!.name;
      }
      if (schedule.user != null && schedule.user!.email.isNotEmpty) {
        return schedule.user!.email
            .split('@')[0]; // Use email prefix as username
      }
      return 'Someone';
    } catch (e) {
      debugPrint('Error getting username: $e');
      return 'Someone';
    }
  }

  // Helper method to format time as HH:MM
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Show edit schedule overlay
  void _showEditScheduleForm(Schedule schedule) {
    final groupProvider =
        Provider.of<GroupSelectionProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => ScheduleFormDialog(
        scheduleToEdit: schedule,
        onFormClosed: _loadSchedules,
        selectedDate: TimezoneService.utcToLocal(schedule.startTime),
        initialGroup: schedule.group ??
            (groupProvider.isPersonalMode ? null : groupProvider.selectedGroup),
      ),
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(Schedule schedule) {
    // Show delete confirmation dialog

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text(
          'Are you sure you want to delete "${schedule.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSchedule(schedule);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Delete schedule
  Future<void> _deleteSchedule(Schedule schedule) async {
    try {
      setState(() => _isLoading = true);
      await ScheduleService.deleteSchedule(schedule.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule deleted successfully')),
        );
      }

      // Reload schedules
      _loadSchedules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete schedule: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Store all schedules for conflict detection
  List<Schedule> _allSchedules = [];

  // Helper method to get conflict availability notices for a specific day
  List<ConflictAvailabilityNotice> _getConflictNoticesForDay(DateTime day) {
    final groupProvider =
        Provider.of<GroupSelectionProvider>(context, listen: false);

    // Only show conflict notices in group mode
    if (groupProvider.isPersonalMode || groupProvider.selectedGroup == null) {
      return [];
    }

    final selectedGroupId = groupProvider.selectedGroup!.id;
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);

    // Check if the selected group has conflicts on this date
    if (!ScheduleConflictDetector.groupHasConflictOnDate(
        selectedGroupId, normalizedDay, _conflictsByDate)) {
      return [];
    }

    final notices = <ConflictAvailabilityNotice>[];

    // Get all schedules for this date from all groups
    final allGroupedSchedules = _groupSchedulesByDate(_allSchedules);
    final allSchedulesForDate = allGroupedSchedules[normalizedDay] ?? [];

    // Find schedules from the selected group
    final selectedGroupSchedules = allSchedulesForDate
        .where((s) => s.group?.id == selectedGroupId)
        .toList();

    // Find conflicting schedules from other groups
    for (final selectedSchedule in selectedGroupSchedules) {
      for (final otherSchedule in allSchedulesForDate) {
        if (otherSchedule.group?.id != selectedGroupId &&
            ScheduleConflictDetector.schedulesOverlap(
                selectedSchedule, otherSchedule)) {
          // Create a conflict notice (avoid duplicates)
          if (!notices.any(
              (notice) => notice.conflictingSchedule.id == otherSchedule.id)) {
            notices.add(ConflictAvailabilityNotice(
              conflictingSchedule: otherSchedule,
              startTime: otherSchedule.startTime,
              endTime: otherSchedule.endTime,
            ));
          }
        }
      }
    }

    return notices;
  }

  // Helper method to get dot color based on schedule
  Color _getDotColor(Schedule schedule, Color defaultColor, int index) {
    if (schedule.color != null && schedule.color!.isNotEmpty) {
      try {
        String colorString = schedule.color!;
        int colorValue;

        if (colorString.startsWith('#')) {
          colorValue = int.parse(colorString.substring(1), radix: 16);
          if (colorString.length == 7) {
            colorValue = 0xFF000000 | colorValue;
          }
        } else {
          // Handle integer color strings like "4284513675"
          colorValue = int.parse(colorString);
        }

        return Color(colorValue);
      } catch (e) {
        debugPrint(
            'Failed to parse schedule color: ${schedule.color}, error: $e');
      }
    }

    // Define a consistent color palette for schedules
    final colors = [
      const Color(0xFF735BF2), // Purple (default)
      const Color(0xFF4CAF50), // Green
      const Color(0xFF2196F3), // Blue
      const Color(0xFFFF9800), // Orange
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple variant
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF607D8B), // Blue Grey
      const Color(0xFF795548), // Brown
      const Color(0xFFFFC107), // Amber
    ];

    // Use different colors for different types of schedules
    if (schedule.group != null) {
      // For group schedules, use consistent colors based on group ID
      final colorIndex = schedule.group!.id.hashCode.abs() % colors.length;
      return colors[colorIndex];
    } else {
      // For personal schedules, use the default color or first color in palette
      return defaultColor;
    }
  }

  Widget _buildCalendarSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final groupProvider =
        Provider.of<GroupSelectionProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF222B45);

    // Determine the current calendar name using provider
    String currentCalendarName = groupProvider.currentSelectionName;

    return Expanded(
      child: Container(
        alignment: Alignment.centerLeft, // untuk positioning child
        child: SizedBox(
          width: 148.0, // ukuran fix
          height: 50.0,
          child: Container(
            padding: const EdgeInsets.only(left: 17.0, right: 17.0),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.1 * 255).round()),
                  offset: const Offset(0, 4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: InkWell(
              onTap: _toggleSidebar,
              borderRadius: BorderRadius.circular(30),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/calendar_selector-icon.svg',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      currentCalendarName,
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.normal,
                          fontSize: 14,
                          fontFamily: 'Arial'),
                      overflow: TextOverflow.ellipsis,
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
}
