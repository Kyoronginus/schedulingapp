import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../../widgets/text_styles.dart';
import '../home/home_screen.dart';
import '../auth/login/login_screen.dart';
import '../routes/app_routes.dart';
import '../utils/utils_functions.dart';

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
    await Future.delayed(Duration(seconds: 2), () {});

    try {
      // Check if user is signed in
      final result = await Amplify.Auth.fetchAuthSession();
      final isSignedIn = result.isSignedIn;

      if (isSignedIn) {
        // User is signed in, navigate to home screen
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        // No user is signed in, navigate to register screen
        Navigator.pushReplacementNamed(context, AppRoutes.register);
      }
    } catch (e) {
      // Error checking auth status, default to register screen
      print('Error checking auth status: $e');
      Navigator.pushReplacementNamed(context, AppRoutes.register);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withOpacity(0.8),
              primaryColor.withOpacity(0.6),
              primaryColor.withOpacity(0.4),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.calendar_today,
                  size: 60,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              // App name
              const Text(
                'Scheduling App',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              // Loading indicator
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
