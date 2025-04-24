import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
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
  String? _userName;

  @override
  void initState() {
    super.initState();
    _fetchUserName(); // Fetch user name on initialization
  }

  Future<void> _fetchUserName() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final nameAttribute = attributes.firstWhere(
        (attr) => attr.userAttributeKey == CognitoUserAttributeKey.name,
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.name,
          value: '',
        ),
      );
      setState(() {
        _userName = nameAttribute.value.isNotEmpty ? nameAttribute.value : null;
      });
    } catch (e) {
      print('❌ Error fetching user name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text("Ini Home Screen")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_userName != null)
            Text('Welcome, $_userName!', style: TextStyle(fontSize: 20)),
          if (_userName == null)
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
