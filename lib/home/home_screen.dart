import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:table_calendar/table_calendar.dart'; // Import table_calendar package
import '../routes/app_routes.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/text_styles.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/custom_button.dart';
import 'dart:convert';
import '../../models/Schedule.dart'; // Import Schedule model
import '../../schedule/schedule_service.dart'; // Import ScheduleService

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Use schedule index since we're removing home tab
  String? _userName;
  Map<DateTime, List<Schedule>> _groupedSchedules = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _loadAllSchedules(); // Load schedules on initialization
  }

  Future<void> _fetchUserName() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();

      // 1. fetch email from Cognito
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final emailAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey == CognitoUserAttributeKey.email,
        orElse: () => AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.email,
          value: '',
        ),
      );
      final email = emailAttr?.value ?? 'no-email@example.com';
      print('📧 User email: $email');

      // 2. GraphQL Query
      final request = GraphQLRequest<String>(
        document: '''
        query GetUser(\$id: ID!) {
          getUser(id: \$id) {
            name
          }
        }
      ''',
        variables: {'id': user.userId},
      );

      final response = await Amplify.API.query(request: request).response;
      final userData = jsonDecode(response.data ?? '{}')['getUser'];

      if (userData == null) {
        print('🔄 Redirecting to profile...');
        Navigator.pushNamed(context, '/profile', arguments: {
          'email': email,
          'userId': user.userId,
        });
      } else {
        setState(() => _userName = userData['name']);
      }
    } catch (e) {
      print('❌ Error: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to fetch user data: $e')),
      // );
    }
  }

  Future<void> _createUserProfile(
      {required String email, required String userId}) async {
    final name = await _promptForName();
    if (name == null || name.isEmpty) return;

    try {
      final request = GraphQLRequest<String>(
        document: '''
      mutation CreateUser(\$input: CreateUserInput!) {
        createUser(input: \$input) {
          id
          name
        }
      }
      ''',
        variables: {
          'input': {
            'id': userId,
            'email': email,
            'name': name,
          }
        },
      );
      await Amplify.API.mutate(request: request);
      setState(() => _userName = name);
    } catch (e) {
      print('❌ User creation failed: $e');
    }
  }

  Future<String?> _promptForName() async {
    String? name;
    await showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        return AlertDialog(
          title: Text("Enter Your Name"),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: "Name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                name = nameController.text.trim();
                Navigator.of(context).pop();
              },
              child: Text("Submit"),
            ),
          ],
        );
      },
    );
    return name;
  }

  Future<void> _loadAllSchedules() async {
    try {
      final schedules = await ScheduleService.loadAllSchedules();
      setState(() {
        _groupedSchedules = _groupSchedulesByDate(schedules);
        _isLoading = false;
      });
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to load schedules: $e')),
      // );
      setState(() => _isLoading = false);
    }
  }

  Map<DateTime, List<Schedule>> _groupSchedulesByDate(
      List<Schedule> schedules) {
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

// widget to display a calendar and a list of schedules
  Widget _buildScheduleList() {
    final day = _selectedDay ?? _focusedDay;
    final schedules = _groupedSchedules.values
        .expand((list) => list)
        .where((s) => isSameDay(s.startTime.getDateTimeInUtc(), day))
        .toList();

    if (schedules.isEmpty) {
      return Center(child: Text('No schedules for this day'));
    }

    return ListView.builder(
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            title: Text(schedule.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${schedule.startTime.format()} 〜 ${schedule.endTime.format()}'),
                if (schedule.description != null) Text(schedule.description!),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text("Home Screen"),
        showBackButton: false, // Hide back button on home screen
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userName == null
              ? CustomButton(
                  label: 'Login',
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.login);
                  },
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Welcome, $_userName ！',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    TableCalendar(
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
                      calendarStyle: const CalendarStyle(
                        markerDecoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _buildScheduleList()),
                  ],
                ),
      bottomNavigationBar: BottomNavBar(currentIndex: _currentIndex),
    );
  }
}
