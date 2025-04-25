import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart'; // Import Amplify for auth checks
import '../routes/app_routes.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/text_styles.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/custom_button.dart';
import '../../auth/logout.dart'; // Import logout logic

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  int _currentIndex = 2;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState(); // Check if the user is logged in
  }

  Future<void> _checkAuthState() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      setState(() {
        _isLoggedIn = user != null; // User is logged in if not null
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
      appBar: CustomAppBar(title: Text("Ini Setting Screen")),
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
