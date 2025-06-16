import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../../routes/app_routes.dart';
import '../../widgets/pin_input_widget.dart';
import '../../widgets/keyboard_aware_scaffold.dart';
import '../../utils/utils_functions.dart';

class ConfirmSignUpScreen extends StatefulWidget {
  final String email;

  const ConfirmSignUpScreen({super.key, required this.email});

  @override
  State<ConfirmSignUpScreen> createState() => _ConfirmSignUpScreenState();
}

class _ConfirmSignUpScreenState extends State<ConfirmSignUpScreen> {
  bool _isLoading = false;
  String _message = "";
  String _verificationCode = "";
  String? _pinError;

  Future<void> _confirmSignUp() async {
    if (_verificationCode.length != 6) {
      setState(() {
        _pinError = "Please enter the complete 6-digit code";
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _message = "";
      _pinError = null;
    });

    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: widget.email,
        confirmationCode: _verificationCode,
      );

      if (!mounted) return;
      if (result.isSignUpComplete) {
        debugPrint('✅ ConfirmSignUp: Email confirmation successful');

        // Note: User record creation is now handled by Lambda triggers
        // No need to manually create user record here
        debugPrint('ℹ️ User record will be created by post-confirmation Lambda trigger');

        if (!mounted) return;
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
    return KeyboardAwareScaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: const Text(
          "Verify Your Account",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Main content container
                Container(
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.verified_user,
                          size: 40,
                          color: primaryColor,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        "Enter Verification Code",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      // Description
                      Text(
                        "We've sent a 6-digit verification code to:",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      // Email
                      Text(
                        widget.email,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // PIN Input
                      PinInputWidget(
                        onCompleted: (pin) {
                          setState(() {
                            _verificationCode = pin;
                            _pinError = null;
                          });
                          _confirmSignUp();
                        },
                        onChanged: (pin) {
                          setState(() {
                            _verificationCode = pin;
                            _pinError = null;
                          });
                        },
                        errorText: _pinError,
                      ),

                      const SizedBox(height: 32),

                      // Confirm button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _confirmSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  "Confirm Sign Up",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Resend code option
                      TextButton(
                        onPressed: _isLoading ? null : _resendCode,
                        child: Text(
                          "Resend Code",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      // Message
                      if (_message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _message,
                            style: TextStyle(
                              color: _message.startsWith("✅") ? Colors.green : Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
