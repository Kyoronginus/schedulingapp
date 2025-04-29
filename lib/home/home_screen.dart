import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../routes/app_routes.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/text_styles.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/custom_button.dart';
import 'dart:convert';

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

      // 1. 安全にemailを取得
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

      // 2. GraphQLクエリ
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データ取得に失敗しました')),
      );
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
