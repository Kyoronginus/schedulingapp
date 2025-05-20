import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';
import '../widgets/custom_app_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import '../models/Schedule.dart';
import '../models/Group.dart';
import '../dynamo/group_service.dart';
import 'schedule_service.dart';
import '../theme/theme_provider.dart';
import '../utils/utils_functions.dart';
import 'create_schedule/schedule_form_screen.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _ScheduleScreenState extends State<ScheduleScreen> {
  final int _currentIndex = 0; // Schedule is the 1st tab (index 0)
  List<Group> _groups = [];
  Group? _selectedGroup;
  bool _isPersonalCalendar = false;
  bool _isLoading = true;
  Map<DateTime, List<Schedule>> _groupedSchedules = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _currentMonth = DateFormat('MMMM').format(DateTime.now());
  int _currentYear = DateTime.now().year;
  String _currentUserId = '';
  final Map<String, bool> _isAdminCache =
      {}; // Cache to store admin status for groups
  bool _showCreateForm = false; // Flag to show/hide the create form overlay

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    _loadGroups();
  }

  Future<void> _getCurrentUserId() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      setState(() {
        _currentUserId = user.userId;
      });
    } catch (e) {
      debugPrint('Error getting current user: $e');
    }
  }

  Future<bool> _isUserAdmin(String groupId) async {
    // Check cache first
    if (_isAdminCache.containsKey(groupId)) {
      return _isAdminCache[groupId]!;
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
        variables: {'userId': _currentUserId, 'groupId': groupId},
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

  Future<void> _loadGroups() async {
    try {
      final groups = await GroupService.getUserGroups();
      setState(() {
        _groups = groups;
        if (groups.isNotEmpty) {
          _selectedGroup = groups.first;
        }
        _isLoading = false;
      });
      _loadSchedules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load groups: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      List<Schedule> schedules = [];

      if (_isPersonalCalendar) {
        // Load schedules from all groups for personal calendar
        schedules = await ScheduleService.loadAllSchedules();
      } else if (_selectedGroup != null) {
        // Load schedules for the selected group
        schedules = await ScheduleService.getGroupSchedules(_selectedGroup!.id);
      }

      setState(() {
        _groupedSchedules = _groupSchedulesByDate(schedules);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load schedules: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Map<DateTime, List<Schedule>> _groupSchedulesByDate(
    List<Schedule> schedules,
  ) {
    final Map<DateTime, List<Schedule>> grouped = {};
    for (final schedule in schedules) {
      final date = DateTime(
        schedule.startTime.getDateTimeInUtc().year,
        schedule.startTime.getDateTimeInUtc().month,
        schedule.startTime.getDateTimeInUtc().day,
      );
      if (grouped[date] == null) {
        grouped[date] = [];
      }
      grouped[date]!.add(schedule);
    }
    return grouped;
  }

  List<Schedule> _getSchedulesForDay(DateTime day) {
    return _groupedSchedules[day] ?? [];
  }

  void _toggleCreateForm() {
    setState(() {
      _showCreateForm = !_showCreateForm;
      // If not already selected, select today's date when opening the form
      if (_showCreateForm && _selectedDay == null) {
        _selectedDay = DateTime.now();
      }
    });
  }

  void _closeCreateForm() {
    setState(() {
      _showCreateForm = false;
    });
    _loadSchedules(); // Reload schedules when closing the form
  }

  // Removed unused method _navigateToAddGroup

  void _selectGroup(Group group) {
    setState(() {
      _selectedGroup = group;
      _isPersonalCalendar = false;
    });
    _loadSchedules();
  }

  void _selectPersonalCalendar() {
    setState(() {
      _isPersonalCalendar = true;
    });
    _loadSchedules();
  }

  void _updateMonthYear(int month, int year) {
    setState(() {
      _focusedDay = DateTime(year, month, 1);
      _currentMonth = DateFormat('MMMM').format(DateTime(year, month, 1));
      _currentYear = year;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final activeColor = isDarkMode ? const Color(0xFF4CAF50) : primaryColor;

    return Scaffold(
      appBar: CustomAppBar(
        title: Text(
          "Schedule",
          style: TextStyle(
            color: isDarkMode ? const Color(0xFF4CAF50) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : null,
        showBackButton: false,
      ),
      body: Stack(
        children: [
          // Main content
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                ),
              )
              : Column(
                children: [
                  // Top row with calendar selector and month/year selector
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      children: [
                        // Calendar selector dropdown
                        Expanded(child: _buildCalendarSelector()),

                        const SizedBox(width: 8),

                        // Month/Year selector
                        Expanded(child: _buildMonthYearSelector()),
                      ],
                    ),
                  ),

                  // Calendar
                  TableCalendar(
                    firstDay: DateTime.utc(2000, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
                        _currentMonth = DateFormat('MMMM').format(focusedDay);
                        _currentYear = focusedDay.year;
                      });
                    },
                    startingDayOfWeek:
                        StartingDayOfWeek.monday, // Start with Monday
                    calendarStyle: CalendarStyle(
                      markerDecoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: activeColor.withAlpha(76), // 0.3 opacity
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                      // Only make Sunday red (last day of week when starting with Monday)
                      weekendTextStyle: const TextStyle(
                        color: Colors.black, // Default color for Saturday
                      ),
                      outsideTextStyle: TextStyle(color: Colors.grey[400]),
                      markersMaxCount: 4,
                      markersAlignment: Alignment.bottomCenter,
                      markerMargin: const EdgeInsets.only(top: 4),
                      markerSize: 6,
                    ),
                    headerVisible: false, // Hide the default header
                    calendarBuilders: CalendarBuilders(
                      // Custom day builder to make only Sunday red
                      defaultBuilder: (context, day, focusedDay) {
                        // Sunday is 7 when starting with Monday
                        final isWeekend = day.weekday == DateTime.sunday;
                        return Center(
                          child: Text(
                            day.day.toString(),
                            style: TextStyle(
                              color: isWeekend ? Colors.red : null,
                            ),
                          ),
                        );
                      },
                      // Custom marker builder for dots under dates
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) return const SizedBox.shrink();

                        // Cast events to List<Schedule>
                        final scheduleEvents =
                            events.map((e) => e as Schedule).toList();

                        // Assign a color to each unique group
                        final colors = <Color>[];
                        for (var schedule in scheduleEvents) {
                          final c = _getDotColor(
                            schedule,
                            activeColor,
                            colors.length,
                          );
                          if (!colors.contains(c)) colors.add(c);
                        }

                        // Limit to 4 dots maximum
                        final dotsToShow =
                            colors.length > 4 ? 4 : colors.length;

                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < dotsToShow; i++)
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors[i],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Schedule list
                  Expanded(child: _buildScheduleList()),
                ],
              ),

          // Form overlay
          if (_showCreateForm)
            Container(
              color: Colors.black.withAlpha(128), // 0.5 opacity
              child: ScheduleFormOverlay(
                onClose: _closeCreateForm,
                selectedDate: _selectedDay ?? DateTime.now(),
                initialGroup: _isPersonalCalendar ? null : _selectedGroup,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleCreateForm,
        backgroundColor: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
        child: Icon(
          _showCreateForm ? Icons.close : Icons.add,
          color: Colors.white,
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: _currentIndex),
    );
  }

  static const double _selectorHeight = 44.0;

  Widget _buildMonthYearSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final activeColor = isDarkMode ? const Color(0xFF4CAF50) : primaryColor;

    return Container(
      height: _selectorHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      foregroundDecoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Calendar icon
          Icon(Icons.calendar_today, color: textColor, size: 20),

          const SizedBox(width: 8),

          // Month and Year display
          Expanded(
            child: Text(
              '$_currentMonth $_currentYear',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Dropdown button
          Icon(Icons.arrow_drop_down, color: textColor),
        ],
      ),
      // Foreground decoration moved up
    ).onTap(() {
      // Show month picker when tapped
      showDialog(
        context: context,
        builder: (BuildContext context) {
          // Track the currently displayed year and month in the picker
          int displayYear = _currentYear;
          int displayMonth = DateFormat('MMMM').parse(_currentMonth).month;

          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                contentPadding: const EdgeInsets.all(16),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with month/year and navigation arrows
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Previous month button
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () {
                              setState(() {
                                if (displayMonth > 1) {
                                  displayMonth--;
                                } else {
                                  displayMonth = 12;
                                  displayYear--;
                                }
                              });
                            },
                          ),

                          // Month and Year display (clickable)
                          GestureDetector(
                            onTap: () {
                              // Show year picker when month/year text is tapped
                              showDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Select Year'),
                                      content: SizedBox(
                                        width: 300,
                                        height: 300,
                                        child: ListView.builder(
                                          itemCount:
                                              101, // 100 years (2000-2100)
                                          itemBuilder: (context, index) {
                                            final year = 2000 + index;
                                            return ListTile(
                                              title: Text('$year'),
                                              selected: year == displayYear,
                                              onTap: () {
                                                setState(() {
                                                  displayYear = year;
                                                });
                                                Navigator.pop(context);
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                              );
                            },
                            child: Text(
                              '${DateFormat('MMMM').format(DateTime(displayYear, displayMonth))} $displayYear',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // Next month button
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              setState(() {
                                if (displayMonth < 12) {
                                  displayMonth++;
                                } else {
                                  displayMonth = 1;
                                  displayYear++;
                                }
                              });
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Calendar grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 1,
                            ),
                        itemCount: 7 * 7, // Header row + up to 6 rows of days
                        itemBuilder: (context, index) {
                          // First row is day headers (Mon, Tue, Wed, etc.)
                          if (index < 7) {
                            final dayNames = [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ];
                            return Center(
                              child: Text(
                                dayNames[index],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      index == 6
                                          ? Colors.red
                                          : null, // Sunday in red
                                ),
                              ),
                            );
                          }

                          // Calculate the day for this grid position
                          final firstDayOfMonth = DateTime(
                            displayYear,
                            displayMonth,
                            1,
                          );
                          final dayOffset =
                              (firstDayOfMonth.weekday - 1) % 7; // 0 = Monday
                          final day = index - 7 - dayOffset + 1;

                          // Check if this position has a valid day for the current month
                          if (day < 1 ||
                              day >
                                  DateTime(
                                    displayYear,
                                    displayMonth + 1,
                                    0,
                                  ).day) {
                            return const SizedBox(); // Empty cell
                          }

                          final date = DateTime(displayYear, displayMonth, day);
                          final isSelected =
                              date.year == _currentYear &&
                              date.month ==
                                  DateFormat(
                                    'MMMM',
                                  ).parse(_currentMonth).month &&
                              date.day == (_selectedDay ?? _focusedDay).day;
                          final isToday =
                              date.year == DateTime.now().year &&
                              date.month == DateTime.now().month &&
                              date.day == DateTime.now().day;

                          // Check if this day is a Sunday
                          final isSunday = date.weekday == DateTime.sunday;

                          return GestureDetector(
                            onTap: () {
                              _updateMonthYear(displayMonth, displayYear);
                              setState(() {
                                _selectedDay = date;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? activeColor
                                        : (isToday
                                            ? activeColor.withAlpha(76)
                                            : null), // 0.3 opacity
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  day.toString(),
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : (isSunday ? Colors.red : null),
                                    fontWeight:
                                        isToday || isSelected
                                            ? FontWeight.bold
                                            : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              _updateMonthYear(displayMonth, displayYear);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeColor,
                            ),
                            child: const Text('Select'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    });
  }

  Widget _buildScheduleList() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final activeColor = isDarkMode ? const Color(0xFF4CAF50) : primaryColor;

    final day = _selectedDay ?? _focusedDay;
    final schedules =
        _groupedSchedules.values
            .expand((list) => list)
            .where((s) => isSameDay(s.startTime.getDateTimeInUtc(), day))
            .toList();

    // Sort schedules by start time
    schedules.sort(
      (a, b) => a.startTime.getDateTimeInUtc().compareTo(
        b.startTime.getDateTimeInUtc(),
      ),
    );

    if (schedules.isEmpty) {
      return Center(
        child: Text(
          'No schedules for this day',
          style: TextStyle(color: textColor),
        ),
      );
    }

    return ListView.builder(
      itemCount: schedules.length,
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (context, index) {
        final schedule = schedules[index];

        // Determine dot color based on group or some other criteria
        final dotColor = _getDotColor(schedule, activeColor, 0);

        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colored dot indicator
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4, right: 12),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),

                // Schedule content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time range
                      Text(
                        '${_formatTime(schedule.startTime.getDateTimeInUtc())}-${_formatTime(schedule.endTime.getDateTimeInUtc())}',
                        style: TextStyle(
                          color: dotColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Title
                      Text(
                        schedule.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: textColor,
                        ),
                      ),

                      // Description
                      if (schedule.description != null &&
                          schedule.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Linkify(
                                  text: schedule.description!,
                                  style: TextStyle(
                                    color:
                                        isDarkMode
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  linkStyle: TextStyle(
                                    color: activeColor,
                                    decoration: TextDecoration.underline,
                                  ),
                                  onOpen: (link) async {
                                    if (await canLaunchUrl(
                                      Uri.parse(link.url),
                                    )) {
                                      await launchUrl(Uri.parse(link.url));
                                    }
                                  },
                                ),
                              ),
                              if (schedule.description!.length > 100)
                                TextButton(
                                  onPressed: () {
                                    // Show full description
                                    showDialog(
                                      context: context,
                                      builder:
                                          (context) => AlertDialog(
                                            title: Text(schedule.title),
                                            content: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Linkify(
                                                    text: schedule.description!,
                                                    style: TextStyle(
                                                      color:
                                                          isDarkMode
                                                              ? Colors.grey[300]
                                                              : Colors
                                                                  .grey[700],
                                                    ),
                                                    linkStyle: TextStyle(
                                                      color: activeColor,
                                                      decoration:
                                                          TextDecoration
                                                              .underline,
                                                    ),
                                                    onOpen: (link) async {
                                                      if (await canLaunchUrl(
                                                        Uri.parse(link.url),
                                                      )) {
                                                        await launchUrl(
                                                          Uri.parse(link.url),
                                                        );
                                                      }
                                                    },
                                                  ),
                                                  if (schedule.location !=
                                                          null &&
                                                      schedule
                                                          .location!
                                                          .isNotEmpty) ...[
                                                    const SizedBox(height: 16),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.location_on,
                                                          size: 16,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Expanded(
                                                          child: GestureDetector(
                                                            onTap: () async {
                                                              // Try to launch as map URL
                                                              final mapUrl =
                                                                  'https://maps.google.com/?q=${Uri.encodeComponent(schedule.location!)}';
                                                              if (await canLaunchUrl(
                                                                Uri.parse(
                                                                  mapUrl,
                                                                ),
                                                              )) {
                                                                await launchUrl(
                                                                  Uri.parse(
                                                                    mapUrl,
                                                                  ),
                                                                );
                                                              }
                                                            },
                                                            child: Text(
                                                              schedule
                                                                  .location!,
                                                              style: TextStyle(
                                                                color:
                                                                    activeColor,
                                                                decoration:
                                                                    TextDecoration
                                                                        .underline,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(context),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ),
                                    );
                                  },
                                  child: Text(
                                    'View more',
                                    style: TextStyle(
                                      color: dotColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                      // Location
                      if (schedule.location != null &&
                          schedule.location!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color:
                                    isDarkMode
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    // Try to launch as map URL
                                    final mapUrl =
                                        'https://maps.google.com/?q=${Uri.encodeComponent(schedule.location!)}';
                                    if (await canLaunchUrl(Uri.parse(mapUrl))) {
                                      await launchUrl(Uri.parse(mapUrl));
                                    }
                                  },
                                  child: Text(
                                    schedule.location!,
                                    style: TextStyle(
                                      color:
                                          isDarkMode
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Options button - only shown for admins
                FutureBuilder<bool>(
                  future:
                      schedule.group != null
                          ? _isUserAdmin(schedule.group!.id)
                          : Future.value(
                            true,
                          ), // Personal schedules are always editable
                  builder: (context, snapshot) {
                    final isAdmin = snapshot.data ?? false;

                    return isAdmin
                        ? IconButton(
                          icon: Icon(
                            Icons.more_vert,
                            color:
                                isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                          ),
                          onPressed: () {
                            // Show options menu for admin
                            showModalBottomSheet(
                              context: context,
                              builder:
                                  (context) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.edit),
                                        title: const Text('Edit Schedule'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _showEditScheduleForm(schedule);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        title: const Text(
                                          'Delete Schedule',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _showDeleteConfirmation(schedule);
                                        },
                                      ),
                                    ],
                                  ),
                            );
                          },
                        )
                        : const SizedBox.shrink(); // Hide button for non-admins
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to format time as HH:MM
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Show edit schedule overlay
  void _showEditScheduleForm(Schedule schedule) {
    setState(() {
      _showCreateForm = true;
    });

    // Use a post-frame callback to ensure the overlay is built before showing the form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => Dialog(
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              child: ScheduleFormOverlay(
                scheduleToEdit: schedule,
                onClose: _closeCreateForm,
                selectedDate: schedule.startTime.getDateTimeInUtc(),
                initialGroup: _isPersonalCalendar ? null : _selectedGroup,
              ),
            ),
      );
    });
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(Schedule schedule) {
    // Show delete confirmation dialog

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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

  // Helper method to get dot color based on schedule
  Color _getDotColor(Schedule schedule, Color defaultColor, int index) {
    // Use different colors for different types of schedules
    if (schedule.group != null) {
      // For group schedules, use different colors based on group
      if (schedule.group!.id == _selectedGroup?.id) {
        return defaultColor;
      } else {
        // Different colors for different groups
        final colors = [
          Colors.blue,
          Colors.purple,
          Colors.teal,
          Colors.orange,
          Colors.pink,
          Colors.amber,
          Colors.cyan,
          Colors.deepOrange,
        ];
        // Use hash of group id to determine color or use index if provided
        final colorIndex =
            index < colors.length
                ? index
                : schedule.group!.id.hashCode % colors.length;
        return colors[colorIndex];
      }
    } else {
      // For personal schedules
      return Colors.blue;
    }
  }

  Widget _buildCalendarSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    // Determine the current calendar name
    String currentCalendarName =
        _isPersonalCalendar
            ? "Personal"
            : _selectedGroup?.name ?? "Select Calendar";

    return Container(
      height: _selectorHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      alignment: Alignment.centerLeft,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: null, // Don't show a selected value in the dropdown itself
          hint: Row(
            children: [
              Icon(Icons.calendar_view_month, color: textColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentCalendarName,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          icon: Icon(Icons.arrow_drop_down, color: textColor),
          isExpanded: true,
          dropdownColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
          items: [
            // Personal Calendar option
            DropdownMenuItem<String>(
              value: "personal",
              child: Text(
                "Personal",
                style: TextStyle(
                  color: textColor,
                  fontWeight:
                      _isPersonalCalendar ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () => _selectPersonalCalendar(),
            ),

            // Divider
            if (_groups.isNotEmpty)
              DropdownMenuItem<String>(
                enabled: false,
                child: Divider(color: textColor.withAlpha(128)), // 0.5 opacity
              ),

            // Group Calendar options
            ..._groups.map(
              (group) => DropdownMenuItem<String>(
                value: group.id,
                child: Text(
                  group.name,
                  style: TextStyle(
                    color: textColor,
                    fontWeight:
                        !_isPersonalCalendar && _selectedGroup?.id == group.id
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                ),
                onTap: () => _selectGroup(group),
              ),
            ),
          ],
          onChanged: (_) {}, // We handle selection in onTap of each item
        ),
      ),
    );
  }
}
