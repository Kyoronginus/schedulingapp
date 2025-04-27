import 'package:flutter/material.dart';
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

  // スケジュール作成画面への遷移
  void _navigateToScheduleForm() {
    Navigator.pushReplacementNamed(context, '/scheduleForm');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text("Schedule Screen")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Current Index: $_currentIndex'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _navigateToScheduleForm,
              child: Text('Create Schedule'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: _currentIndex),
    );
  }
}
