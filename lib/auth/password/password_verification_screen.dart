import 'dart:async';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../../utils/utils_functions.dart';
import '../../widgets/pin_input_widget.dart';
import '../../widgets/keyboard_aware_scaffold.dart';
import '../../routes/app_routes.dart';
import '../../services/secure_storage_service.dart';

enum PasswordResetMode { forgotPassword, changePassword }

/// Unified password verification screen for both forgot password and change password flows
class PasswordVerificationScreen extends StatefulWidget {
  final String email;
  final String newPassword;
  final PasswordResetMode mode;

  const PasswordVerificationScreen({
    super.key,
    required this.email,
    required this.newPassword,
    required this.mode,
  });

  @override
  State<PasswordVerificationScreen> createState() => _PasswordVerificationScreenState();
}

class _PasswordVerificationScreenState extends State<PasswordVerificationScreen> {
  bool _isLoading = false;
  String _verificationCode = "";
  String? _pinError;
  Timer? _resendCooldownTimer;
  int _resendCooldown = 0;
  bool _isResending = false;

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _resendCooldown--;
          if (_resendCooldown <= 0) {
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyCode() async {
    if (_verificationCode.length != 6) {
      setState(() {
        _pinError = "Please enter the complete 6-digit code";
      });
      return;
    }

    // Basic validation - check if code contains only digits
    if (!RegExp(r'^\d{6}$').hasMatch(_verificationCode)) {
      setState(() {
        _pinError = "Verification code must be 6 digits";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _pinError = null;
    });

    // Make the final API call with all collected data
    try {
      debugPrint('🔐 Confirming password ${widget.mode.name} for: ${widget.email}');
      await Amplify.Auth.confirmResetPassword(
        username: widget.email,
        newPassword: widget.newPassword,
        confirmationCode: _verificationCode,
      );
      debugPrint('✅ Password ${widget.mode.name} confirmed successfully');

      if (!mounted) return;

      if (widget.mode == PasswordResetMode.forgotPassword) {
        // For forgot password: sign out and go to login
        try {
          debugPrint('🚪 Signing out user to clear session...');
          await Amplify.Auth.signOut();
          debugPrint('✅ User signed out successfully');
        } catch (e) {
          debugPrint('⚠️ Sign out error: $e');
        }

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully! Please log in with your new password.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate back to login screen
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      } else {
        // For change password: stay signed in and return to profile
        debugPrint('🔄 Change password mode: staying signed in and returning to profile');

        // Update the stored password
        try {
          await SecureStorageService.storePassword(widget.newPassword);
          debugPrint('✅ Updated stored password in secure storage');
        } catch (e) {
          debugPrint('⚠️ Failed to update stored password: $e');
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Return to profile screen with success result
        debugPrint('🏠 Navigating back to profile screen with success result');

        // Pop back to change password screen first with success result
        Navigator.of(context).pop(true);

      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          if (e.message.toLowerCase().contains('code') ||
              e.message.toLowerCase().contains('invalid') ||
              e.message.toLowerCase().contains('expired') ||
              e.message.toLowerCase().contains('confirmation')) {
            _pinError = "Invalid or expired verification code. Please try again.";
          } else if (e.message.toLowerCase().contains('password')) {
            _pinError = "Password does not meet requirements.";
          } else {
            _pinError = "${widget.mode == PasswordResetMode.forgotPassword ? 'Reset' : 'Change'} failed: ${e.message}";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pinError = "An error occurred during password ${widget.mode.name}. Please try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      await Amplify.Auth.resetPassword(username: widget.email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new verification code has been sent.'),
            backgroundColor: Colors.green,
          ),
        );
        _startCooldown();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend code: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChangePassword = widget.mode == PasswordResetMode.changePassword;
    
    return KeyboardAwareScaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: Text(
          isChangePassword ? "Verify Email" : "Verify Reset Code",
          style: const TextStyle(
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
                Container(
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        spreadRadius: 2,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isChangePassword ? Icons.email_outlined : Icons.lock_reset,
                          size: 40,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isChangePassword ? "Check Your Email" : "Enter Verification Code",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "We've sent a 6-digit verification code to:",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
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
                      PinInputWidget(
                        primaryColor: primaryColor,
                        onCompleted: (pin) {
                          setState(() => _verificationCode = pin);
                          _verifyCode();
                        },
                        onChanged: (pin) {
                          setState(() {
                            _verificationCode = pin;
                            if (_pinError != null) _pinError = null;
                          });
                        },
                        errorText: _pinError,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyCode,
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
                                  "Verify Code",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _resendCooldown > 0 || _isResending ? null : _resendCode,
                        child: _isResending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : Text(
                                _resendCooldown > 0
                                    ? "Resend in ${_resendCooldown}s"
                                    : "Didn't receive a code? Resend",
                                style: TextStyle(
                                  color: _resendCooldown > 0 || _isResending
                                      ? Colors.grey
                                      : primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
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
