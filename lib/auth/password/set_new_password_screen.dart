import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/utils_functions.dart';
import '../../widgets/keyboard_aware_scaffold.dart';
import '../../widgets/enhanced_password_field.dart';
import '../../widgets/password_validation_widget.dart';
import '../../theme/theme_provider.dart';
import 'password_verification_screen.dart';

/// Second phase of the forgot password flow - password collection
class ForgotPasswordPasswordScreen extends StatefulWidget {
  final String email;

  const ForgotPasswordPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  State<ForgotPasswordPasswordScreen> createState() => _ForgotPasswordPasswordScreenState();
}

class _ForgotPasswordPasswordScreenState extends State<ForgotPasswordPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _passwordsMatch = false;
  bool _passwordIsValid = false;
  String? _confirmPasswordInlineError;

  @override
  void initState() {
    super.initState();
    // Add listeners to controllers to update the UI in real-time
    _newPasswordController.addListener(_validateMatchingPasswords);
    _confirmPasswordController.addListener(_validateMatchingPasswords);
  }

  @override
  void dispose() {
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateMatchingPasswords() {
    final password = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _passwordIsValid = PasswordValidator.isPasswordValid(password);
      _passwordsMatch = password.isNotEmpty &&
                      confirmPassword.isNotEmpty &&
                      password == confirmPassword &&
                      _passwordIsValid;

      if (confirmPassword.isNotEmpty && password != confirmPassword) {
        _confirmPasswordInlineError = "Passwords do not match";
      } else {
        _confirmPasswordInlineError = null;
      }
    });
  }



  Future<void> _proceedToVerification() async {
    // Validate passwords
    if (_newPasswordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a new password';
      });
      return;
    }

    if (_confirmPasswordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please confirm your password';
      });
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    // Validate password strength
    if (!PasswordValidator.isPasswordValid(_newPasswordController.text)) {
      final passwordError = PasswordValidator.validatePassword(_newPasswordController.text);
      setState(() {
        _errorMessage = passwordError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Navigate to verification screen with password data
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PasswordVerificationScreen(
            email: widget.email,
            newPassword: _newPasswordController.text,
            mode: PasswordResetMode.forgotPassword,
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return KeyboardAwareScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Create New Password",
          style: TextStyle(
            color: isDarkMode ? const Color(0xFF4CAF50) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : primaryColor,
        iconTheme: IconThemeData(
          color: isDarkMode ? const Color(0xFF4CAF50) : Colors.white,
        ),
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
                    color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.1),
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
                          color: isDarkMode
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                              : primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 40,
                          color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        "Create New Password",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      // Description
                      Text(
                        "Enter your new password below",
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // New Password field
                      EnhancedPasswordField(
                        controller: _newPasswordController,
                        focusNode: _newPasswordFocus,
                        hintText: "Enter your new password",
                        labelText: "New password",
                        showValidationIcon: _newPasswordController.text.isNotEmpty,
                        isValid: _passwordIsValid,
                        hasMismatch: _newPasswordController.text.isNotEmpty && !_passwordIsValid,
                        onChanged: _validateMatchingPasswords,
                      ),

                      const SizedBox(height: 16),

                      // Confirm Password field
                      EnhancedPasswordField(
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocus,
                        hintText: "Confirm your new password",
                        labelText: "Confirm new password",
                        showValidationIcon: _newPasswordController.text.isNotEmpty && _confirmPasswordController.text.isNotEmpty && _passwordIsValid,
                        isValid: _passwordsMatch,
                        hasMismatch: _confirmPasswordController.text.isNotEmpty && (!_passwordsMatch || !_passwordIsValid),
                        inlineError: _confirmPasswordInlineError,
                        onChanged: _validateMatchingPasswords,
                      ),
                      // Password validation criteria (below confirm password)
                      PasswordValidationWidget(
                        password: _newPasswordController.text,
                        showValidation: _newPasswordController.text.isNotEmpty,
                      ),

                      const SizedBox(height: 24),

                      // Error message
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.red.withValues(alpha: 0.2)
                                : Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.red.withValues(alpha: 0.5)
                                  : Colors.red[200]!,
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Continue button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _proceedToVerification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  "Continue",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
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
