import 'package:flutter/material.dart';
import 'package:schedulingapp/widgets/custom_button.dart';
import '../routes/app_routes.dart'; // 必要に応じてインポート
import '../../widgets/custom_app_bar.dart';
import '../../widgets/bottom_nav_bar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateToScheduleForm() {
    Navigator.pushReplacementNamed(context, '/scheduleForm');
  }

  void _navigateToAddGroup() {
    Navigator.pushNamed(context, '/addGroup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text("Schedule Screen")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomButton(
              onPressed: _navigateToScheduleForm,
              label: 'Create Schedule',
            ),
            SizedBox(height: 20),
            CustomButton(
              onPressed: _navigateToAddGroup,
              label: 'Create Group',
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: _currentIndex),
    );
  }
}
