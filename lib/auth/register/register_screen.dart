import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'confirm_signup_screen.dart';
import '../../utils/utils_functions.dart';
import '../../routes/app_routes.dart';
import '../auth_service.dart';
import '../../widgets/keyboard_aware_scaffold.dart';
import '../../widgets/enhanced_password_field.dart';
import '../../widgets/password_validation_widget.dart';
import '../../theme/theme_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final nameController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;
  bool _passwordsMatch = false;
  bool _passwordIsValid = false;
  String? _confirmPasswordInlineError;

  @override
  void initState() {
    super.initState();
    // Add listeners to controllers to update the UI in real-time
    passwordController.addListener(_validateMatchingPasswords);
    confirmPasswordController.addListener(_validateMatchingPasswords);
  }

  @override
  void dispose() {
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _validateMatchingPasswords() {
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

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

  Future<void> _registerUser() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final name = nameController.text.trim();

    try {
      // Validate inputs
      String? error;
      if (name.isEmpty) {
        error = 'Please enter your name';
      } else if (email.isEmpty) {
        error = 'Please enter your email';
      } else if (password.isEmpty) {
        error = 'Please enter a password';
      } else if (!PasswordValidator.isPasswordValid(password)) {
        error = PasswordValidator.validatePassword(password);
      } else if (password != confirmPassword) {
        error = 'Passwords do not match';
      }

      if (error != null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = error;
        });
        return;
      }

      // Sign up the user with AWS Cognito
      final signUpResult = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            CognitoUserAttributeKey.email: email,
            CognitoUserAttributeKey.name: name,
          },
        ),
      );

      if (!mounted) return;

      // Navigate to ConfirmSignUpScreen
      if (signUpResult.isSignUpComplete) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmSignUpScreen(email: email),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.contains("already exists") ||
          e.message.contains("username exists")) {
        try {
          await Amplify.Auth.resendSignUpCode(username: email);

          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConfirmSignUpScreen(email: email),
            ),
          );
        } on AuthException catch (resendError) {
          if (!mounted) return;
          if (resendError.message.contains("already confirmed")) {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          } else {
            setState(() {
              _errorMessage = resendError.message;
            });
          }
          return;
        }
      }
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final success = await signInWithGoogle(context);

      if (success && mounted) {
        // Navigate to schedule screen on successful login
        Navigator.pushReplacementNamed(context, AppRoutes.schedule);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign In Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFacebookSignIn() async {
    setState(() => _isLoading = true);

    try {
      final success = await signInWithFacebook(context);

      if (success && mounted) {
        // Navigate to schedule screen on successful login
        Navigator.pushReplacementNamed(context, AppRoutes.schedule);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Facebook Sign In Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final inputDecorationTheme = InputDecoration(
      // Theme-aware hint and label styles
      hintStyle: TextStyle(
        color: isDarkMode ? Colors.white54 : const Color(0xFF999999),
      ),
      labelStyle: TextStyle(
        color: isDarkMode ? Colors.white70 : const Color(0xFF999999),
      ),

      // Theme-aware border styles
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(
          color: isDarkMode ? Colors.grey.shade600 : secondaryColor,
          width: 1.5,
        ),
      ),

      // Theme-aware focused border
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(
          color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
          width: 1.5,
        ),
      ),
    );

    return KeyboardAwareScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          // Create account text
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Create your Account",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF222B45),
                    ),
                    textAlign: TextAlign.start),
                const SizedBox(height: 8),
                // Name field
                TextField(
                  controller: nameController,
                  decoration: inputDecorationTheme.copyWith(
                    labelText: "Name",
                    hintText: "Enter your name",
                  ),
                ),
                const SizedBox(height: 16),
                // Email field
                TextField(
                  controller: emailController,
                  decoration: inputDecorationTheme.copyWith(
                      labelText: "Email", hintText: "Enter your email"),
                ),
                const SizedBox(height: 16),
                // Password field
                EnhancedPasswordField(
                  controller: passwordController,
                  focusNode: _passwordFocus,
                  hintText: "Enter your password",
                  labelText: "Password",
                  showValidationIcon: passwordController.text.isNotEmpty,
                  isValid: _passwordIsValid,
                  hasMismatch:
                      passwordController.text.isNotEmpty && !_passwordIsValid,
                  onChanged: _validateMatchingPasswords,
                ),
                const SizedBox(height: 16),
                // Confirm Password field
                EnhancedPasswordField(
                  controller: confirmPasswordController,
                  focusNode: _confirmPasswordFocus,
                  hintText: "Confirm your password",
                  labelText: "Confirm password",
                  showValidationIcon: passwordController.text.isNotEmpty &&
                      confirmPasswordController.text.isNotEmpty &&
                      _passwordIsValid,
                  isValid: _passwordsMatch,
                  hasMismatch: confirmPasswordController.text.isNotEmpty &&
                      (!_passwordsMatch || !_passwordIsValid),
                  inlineError: _confirmPasswordInlineError,
                  onChanged: _validateMatchingPasswords,
                ),
                // Password validation criteria (moved below confirm password)
                PasswordValidationWidget(
                  password: passwordController.text,
                  showValidation: passwordController.text.isNotEmpty,
                ),
                const SizedBox(height: 16),
                // Register button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(
                            color: isDarkMode ? Colors.white : primaryColor,
                          )
                        : const Text(
                            "Register",
                            style: TextStyle(
                              fontSize: 17,
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
                        color: Colors.red,
                        fontWeight: FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),
                // Login link
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: isDarkMode ? Colors.grey.shade600 : const Color(0xFFCACACA),
                        thickness: 1.5,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "OR",
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey.shade400 : const Color(0xFFCACACA),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: isDarkMode ? Colors.grey.shade600 : const Color(0xFFCACACA),
                        thickness: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSocialButton(
                  icon: SvgPicture.asset(
                    'assets/icons/google-icon.svg',
                  ),
                  text: "Continue with Google",
                  onPressed: _handleGoogleSignIn,
                  backgroundColor: isDarkMode ? const Color(0xFF3A3A3A) : Colors.white,
                  textColor: isDarkMode ? Colors.white : Colors.black87,
                ),
                const SizedBox(height: 24),
                _buildSocialButton(
                  icon: SvgPicture.asset(
                    'assets/icons/facebook-icon.svg',
                  ),
                  text: "Continue with Facebook",
                  onPressed: _handleFacebookSignIn,
                  backgroundColor: isDarkMode ? const Color(0xFF3A3A3A) : Colors.white,
                  textColor: isDarkMode ? Colors.white : Colors.black,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account?",
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : const Color(0xFF999999),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                            context, AppRoutes.login);
                      },
                      child: Text(
                        "Login",
                        style: TextStyle(
                          color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required Widget icon,
    required String text,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color textColor,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          side: BorderSide(
            color: isDarkMode ? Colors.grey.shade600 : secondaryColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: icon,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
