import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../../utils/utils_functions.dart'; // Assuming primaryColor is defined here
import '../../services/secure_storage_service.dart';
import '../../widgets/keyboard_aware_scaffold.dart';
import '../../routes/app_routes.dart';
import 'password_verification_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordFocus = FocusNode();
  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  String? _errorMessage;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // State for responsive UI feedback
  bool _passwordsMatch = false;
  final bool _hasAttemptedSubmit = false;
  bool _currentPasswordMatches = false;
  String? _storedPassword;

  // State for inline error messages
  String? _currentPasswordInlineError;
  String? _confirmPasswordInlineError;

  @override
  void initState() {
    super.initState();
    // Load stored password for validation
    _loadStoredPassword();

    // Add listeners to controllers to update the UI in real-time
    _currentPasswordController.addListener(_validateCurrentPassword);
    _newPasswordController.addListener(_validateMatchingPasswords);
    _confirmPasswordController.addListener(_validateMatchingPasswords);

    // Add listeners to focus nodes to rebuild on focus change
    _currentPasswordFocus.addListener(() => setState(() {}));
    _newPasswordFocus.addListener(() => setState(() {}));
    _confirmPasswordFocus.addListener(() => setState(() {}));
  }

  Future<void> _loadStoredPassword() async {
    try {
      _storedPassword = await SecureStorageService.getPassword();
      // Validate current password if there's already text in the field
      if (_currentPasswordController.text.isNotEmpty) {
        _validateCurrentPassword();
      }
    } catch (e) {
      debugPrint('Error loading stored password: $e');
    }
  }

  void _validateCurrentPassword() {
    setState(() {
      if (_currentPasswordController.text.isNotEmpty &&
          _storedPassword != null) {
        _currentPasswordMatches =
            _currentPasswordController.text == _storedPassword;
        _currentPasswordInlineError = _currentPasswordMatches
            ? null
            : 'The password input is incorrect.';
      } else {
        _currentPasswordMatches = false;
        _currentPasswordInlineError = null;
      }
    });
  }

  void _validateMatchingPasswords() {
    setState(() {
      if (_newPasswordController.text.isNotEmpty &&
          _confirmPasswordController.text.isNotEmpty) {
        _passwordsMatch =
            _newPasswordController.text == _confirmPasswordController.text;
        _confirmPasswordInlineError =
            _passwordsMatch ? null : "Passwords don't match.";
      } else {
        _confirmPasswordInlineError = null;
      }
    });
  }

  @override
  void dispose() {
    // Clean up controllers and focus nodes
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    _currentPasswordFocus.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }



  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    List<String> requirements = [];

    if (value.length < 8) {
      requirements.add('at least 8 characters');
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      requirements.add('uppercase letter');
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      requirements.add('lowercase letter');
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      requirements.add('number');
    }

    if (requirements.isNotEmpty) {
      return 'Password needs: ${requirements.join(', ')}';
    }

    return null;
  }

  String? _validateCurrentPasswordField(String? value) {
    if (value == null || value.isEmpty) {
      return 'Current password is required';
    }
    // The specific "incorrect password" message is now handled by the inline helper text
    return null;
  }

  // Helper to determine the color of the text field border
  Color _getBorderColor(FocusNode focusNode,
      {bool isValid = false, bool hasMismatch = false}) {
    if (focusNode.hasFocus) {
      if (hasMismatch) return Colors.red;
      return isValid ? Colors.green : primaryColor;
    }
    return Colors.white; // Default color when not focused
  }

  // Helper to get the password match icon for new passwords
  Widget? _getNewPasswordMatchIcon() {
    if (_newPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty) {
      return Icon(
        _passwordsMatch ? Icons.check_circle : Icons.cancel,
        color: _passwordsMatch ? Colors.green : Colors.red,
      );
    }
    return null;
  }

  Future<void> _validateAndSendVerificationCode() async {
    // Validate all password fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check current password matches
    if (!_currentPasswordMatches) {
      setState(() {
        _errorMessage = 'Current password is incorrect';
      });
      return;
    }

    // Check new passwords match
    if (!_passwordsMatch) {
      setState(() {
        _errorMessage = 'New passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user email from attributes
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final emailAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey == CognitoUserAttributeKey.email,
        orElse: () => throw Exception('Email not found in user attributes'),
      );
      final email = emailAttr.value;

      // Send verification code
      await Amplify.Auth.resetPassword(username: email);

      if (mounted) {
        // Navigate to verification screen with password data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PasswordVerificationScreen(
              email: email,
              newPassword: _newPasswordController.text,
              mode: PasswordResetMode.changePassword,
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = 'Failed to send verification code: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- UI State Calculation ---
    final currentPasswordHasInput =
        _currentPasswordController.text.isNotEmpty;
    final currentPasswordMismatch = currentPasswordHasInput &&
        _storedPassword != null &&
        !_currentPasswordMatches;
    final passwordsHaveInput = _newPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty;
    final passwordMismatch = passwordsHaveInput && !_passwordsMatch;

    final currentPasswordBorderColor = _getBorderColor(
        _currentPasswordFocus,
        isValid: currentPasswordHasInput && _currentPasswordMatches,
        hasMismatch: currentPasswordMismatch);
    final newPasswordBorderColor = _getBorderColor(_newPasswordFocus,
        isValid: passwordsHaveInput && _passwordsMatch,
        hasMismatch: passwordMismatch);
    final confirmPasswordBorderColor = _getBorderColor(_confirmPasswordFocus,
        isValid: passwordsHaveInput && _passwordsMatch,
        hasMismatch: passwordMismatch);

    return KeyboardAwareScaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor,
              primaryColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            // Header with back button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        "Change Password",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 44), // Balance the back button
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                    key: _formKey,
                    autovalidateMode: _hasAttemptedSubmit
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),

                        // Logo or app icon
                        Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.lock_reset,
                              size: 50,
                              color: primaryColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Current password field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              focusNode: _currentPasswordFocus,
                              controller: _currentPasswordController,
                              decoration: InputDecoration(
                                hintText: "Current Password",
                                fillColor: Colors.white,
                                filled: true,
                                prefixIcon: Icon(Icons.lock_outline,
                                    color: primaryColor),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (currentPasswordHasInput &&
                                        _storedPassword != null)
                                      Icon(
                                        _currentPasswordMatches
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: _currentPasswordMatches
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        _obscureCurrentPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: primaryColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureCurrentPassword =
                                              !_obscureCurrentPassword;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(
                                      color: Colors.white, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(
                                      color: currentPasswordBorderColor,
                                      width: 2),
                                ),
                              ),
                              obscureText: _obscureCurrentPassword,
                              validator: _validateCurrentPasswordField,
                            ),
                            if (_currentPasswordInlineError != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 6, left: 16),
                                child: Text(
                                  _currentPasswordInlineError!,
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // New password field
                        TextFormField(
                          focusNode: _newPasswordFocus,
                          controller: _newPasswordController,
                          decoration: InputDecoration(
                            hintText: "New Password",
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(Icons.lock, color: primaryColor),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_getNewPasswordMatchIcon() != null)
                                  _getNewPasswordMatchIcon()!,
                                IconButton(
                                  icon: Icon(
                                    _obscureNewPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: primaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureNewPassword =
                                          !_obscureNewPassword;
                                    });
                                  },
                                ),
                              ],
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                  color: newPasswordBorderColor, width: 2),
                            ),
                          ),
                          obscureText: _obscureNewPassword,
                          validator: _validatePassword,
                        ),

                        const SizedBox(height: 16),

                        // Confirm new password field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              focusNode: _confirmPasswordFocus,
                              controller: _confirmPasswordController,
                              decoration: InputDecoration(
                                hintText: "Confirm New Password",
                                fillColor: Colors.white,
                                filled: true,
                                prefixIcon:
                                    Icon(Icons.lock, color: primaryColor),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_getNewPasswordMatchIcon() != null)
                                      _getNewPasswordMatchIcon()!,
                                    IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: primaryColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(
                                      color: Colors.white, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(
                                      color: confirmPasswordBorderColor,
                                      width: 2),
                                ),
                              ),
                              obscureText: _obscureConfirmPassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _newPasswordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            if (_confirmPasswordInlineError != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 6, left: 16),
                                child: Text(
                                  _confirmPasswordInlineError!,
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Forgot Password link
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, AppRoutes.forgotPassword);
                            },
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Change password button - validates and sends verification code
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _validateAndSendVerificationCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? CircularProgressIndicator(color: primaryColor)
                                : const Text(
                                    "Change Password",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
