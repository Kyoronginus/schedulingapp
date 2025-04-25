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
      final userId = user.userId;

      final request = GraphQLRequest<String>(
        document: '''
        query GetUser {
          getUser(id: "$userId") {
            name
          }
        }
      ''',
      );

      final response = await Amplify.API.query(request: request).response;
      final data = response.data;

      if (data == null) {
        print('❌ No data received from the GraphQL query.');
        Navigator.pushReplacementNamed(context, AppRoutes.setUserName);
        return; // データがない場合、処理を終了
      }

      final decoded = jsonDecode(data);

      // getUserのデータがnullか、nameがnullの場合
      if (decoded['getUser'] == null || decoded['getUser']['name'] == null) {
        print('❌ User data not found, navigating to set username screen.');
        Navigator.pushReplacementNamed(context, AppRoutes.setUserName);
      } else {
        final name = decoded['getUser']['name'];
        setState(() {
          _userName = name;
        });
      }
    } catch (e) {
      print('❌ Error fetching user name from DynamoDB: $e');
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
