import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart'; // Import Amplify for auth checks
import '../../widgets/custom_app_bar.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/custom_button.dart';
import '../../auth/logout.dart'; // Import logout logic

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  int _currentIndex = 3; // Setting is now the 4th tab (index 3)
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState(); // Check if the user is logged in
  }

  Future<void> _checkAuthState() async {
    try {
      await Amplify.Auth.getCurrentUser(); // Just check if this succeeds
      setState(() {
        _isLoggedIn = true; // User is logged in
      });
    } catch (e) {
      setState(() {
        _isLoggedIn = false; // User is not logged in
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: Text("Ini Setting Screen")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Current Index: $_currentIndex'),
            const SizedBox(height: 16),
            if (_isLoggedIn) // Show logout button only if logged in
              CustomButton(
                label: 'Logout',
                onPressed: () => logout(context), // Call the logout function
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: _currentIndex),
    );
  }
}
