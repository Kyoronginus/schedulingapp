import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/text_styles.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/custom_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text("Ini Home Screen")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Current Index: $_currentIndex'),
          const SizedBox(height: 20),
          CustomButton(
            label: 'Login',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.login);
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: _currentIndex),
    );
  }
}
