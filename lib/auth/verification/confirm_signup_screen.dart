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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _message = "";
    });

    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: widget.email,
        confirmationCode: codeController.text.trim(),
      );

      if (!mounted) return;
      if (result.isSignUpComplete) {
        debugPrint('✅ ConfirmSignUp: Email confirmation successful');
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '❌ ${e.message}';
      });
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendCode() async{
    if (!mounted) return;
    setState((){
      _isLoading = true;
      _message = "";
    });

    try{
      final result = await Amplify.Auth.resendSignUpCode(username: widget.email);
      if (!mounted) return;
      setState(() {
        _message = '✅ Code resent to ${result.codeDeliveryDetails.destination}';
      });
    } on AuthException catch (e){
      if (!mounted) return;
      setState(() {
        _message = '❌ ${e.message}';
      });
    } finally{
      // ignore: control_flow_in_finally
      if (!mounted) return;
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
            const SizedBox(height: 8),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Verification Code'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _confirmSignUp,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Confirm Sign Up"),
            ),
            TextButton(
              onPressed: _isLoading ? null : _resendCode,
              child: const Text("Resend Code"),
            ),
            Text(
              _message, 
              style: TextStyle(
                color: _message.startsWith("✅") ?Colors.green :Colors.red,
              )
            ),
          ],
        ),
      ),
    );
  }
}