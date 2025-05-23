import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../../routes/app_routes.dart';


class ConfirmSignUpScreen extends StatefulWidget {
  final String email;

  const ConfirmSignUpScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<ConfirmSignUpScreen> createState() => _ConfirmSignUpScreenState();
}

class _ConfirmSignUpScreenState extends State<ConfirmSignUpScreen> {
  final codeController = TextEditingController();
  bool _isLoading = false;
  String _message = "";

  Future<void> _confirmSignUp() async {
    setState(() {
      _isLoading = true;
      _message = "";
    });

    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: widget.email,
        confirmationCode: codeController.text.trim(),
      );

      if (result.isSignUpComplete) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } on AuthException catch (e) {
      setState(() {
        _message = '❌ ${e.message}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter Verification Code")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("We’ve sent a verification code to: ${widget.email}"),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Verification Code'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _confirmSignUp,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text("Confirm Sign Up"),
            ),
            SizedBox(height: 16),
            Text(_message, style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}