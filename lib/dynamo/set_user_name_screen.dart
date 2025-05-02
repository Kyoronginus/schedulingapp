import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../amplifyconfiguration.dart';
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import 'dart:convert';
import '../models/User.dart';
import '../models/Group.dart';

class SetUserNameScreen extends StatefulWidget {
  const SetUserNameScreen({super.key});

  @override
  State<SetUserNameScreen> createState() => _SetUserNameScreenState();
}

class _SetUserNameScreenState extends State<SetUserNameScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final currentUser = await Amplify.Auth.getCurrentUser();
      final userId = currentUser.userId;

      final attributes = await Amplify.Auth.fetchUserAttributes();
      final email = attributes
          .firstWhere(
              (attr) => attr.userAttributeKey == CognitoUserAttributeKey.email)
          .value;

      // Create a new User instance
      final newUser = User(
        id: userId,
        name: name,
        email: email,
      );

      final request = ModelMutations.create(newUser);
      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        print('GraphQL Errors: ${response.errors}');
        throw Exception(
            'Failed to create user: ${response.errors.map((e) => e.message).join(', ')}');
      }

      if (response.data == null) {
        throw Exception('Failed to create user: No data returned');
      }

      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      print("❌ Error saving name: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Error: ${e.toString().replaceAll('Exception: ', '')}")),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _skip() {
    // Navigate to the next screen without saving the name
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Set Your Name")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Please enter your name:"),
            TextField(controller: _nameController),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveName,
                  child: _isSaving ? CircularProgressIndicator() : Text("Save"),
                ),
                TextButton(
                  onPressed: _isSaving ? null : _skip,
                  child: Text("Skip"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
