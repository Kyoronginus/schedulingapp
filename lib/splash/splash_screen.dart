import 'package:flutter/material.dart';
import '../../widgets/text_styles.dart';
import '../home/home_screen.dart';
import '../auth/login/login_screen.dart';
import '../routes/app_routes.dart';

//onboarding screen for the app
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHomeScreen();
  }

  void _navigateToHomeScreen() async {
    await Future.delayed(Duration(seconds: 3), () {});
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: Text(
        'Welcome to Scheduling App',
      ),
    ));
  }
}
