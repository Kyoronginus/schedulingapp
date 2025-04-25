import 'package:flutter/material.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../verification/confirm_signup_screen.dart'; // Import ConfirmSignUpScreen

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
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      // Sign up the user with AWS Cognito
      final signUpResult = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: CognitoSignUpOptions(userAttributes: {
          CognitoUserAttributeKey.email: email,
        }),
      );

      // Navigate to ConfirmSignUpScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmSignUpScreen(email: email),
        ),
      );
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
