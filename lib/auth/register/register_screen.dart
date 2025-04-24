import 'package:flutter/material.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController(); // Add name controller

  Future<void> _registerUser() async {
    try {
      final name = nameController.text.trim(); // Get name
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: CognitoSignUpOptions(userAttributes: {
          CognitoUserAttributeKey.email: email,
          // CognitoUserAttributeKey.name: name, // Save name in Cognito
        }),
      );

      // // Save name to DynamoDB
      // await Amplify.DataStore.save(
      //   User(name: name, email: email), // Replace with your DynamoDB model
      // );

      print('✅ Sign up complete: ${result.isSignUpComplete}');
    } on AuthException catch (e) {
      print('❌ Error: ${e.message}');
    } catch (e) {
      print('❌ Unexpected error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
                controller: nameController, // Add name field
                decoration: InputDecoration(labelText: 'Name')),
            TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email')),
            TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true),
            ElevatedButton(
              onPressed: _registerUser,
              child: Text("Register"),
            ),
          ],
        ),
      ),
    );
  }
}
