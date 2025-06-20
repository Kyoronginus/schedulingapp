import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../../utils/utils_functions.dart';
import '../password/forgot_password_screen.dart';
import '../../routes/app_routes.dart';
import '../../widgets/exception_message.dart';
import '../../widgets/keyboard_aware_scaffold.dart';
import '../../providers/group_selection_provider.dart';
import '../../theme/theme_provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  final bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await login(_emailController.text, _passwordController.text);
      if (!mounted) return;

      final groupProvider =
          Provider.of<GroupSelectionProvider>(context, listen: false);
      await groupProvider.reinitialize();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.schedule);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = authErrorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      if (message.contains('not confirmed')) {
        Navigator.pushReplacementNamed(context, AppRoutes.register);
      }
      setState(() {
        _errorMessage = message;
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
          const SizedBox(height: 96),
          // Content
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
                // Logo or app icon
                Text("Login to your Account",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF222B45),
                    ),
                    textAlign: TextAlign.start),
                const SizedBox(height: 8),
                // Email field with styled containe
                TextField(
                  controller: _emailController,
                  decoration: inputDecorationTheme.copyWith(
                      labelText: "Email", hintText: "Enter your email"),
                ),

                const SizedBox(height: 16),
                // Password field
                TextField(
                  controller: _passwordController,
                  decoration: inputDecorationTheme.copyWith(
                    labelText: "Password",
                    hintText: "Enter your password",
                  ),
                  obscureText: _obscurePassword,
                ),
                // Forgot Password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Login button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
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
                            "Login",
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
                ), // Register link
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
                      "Don't have an account?",
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : const Color(0xFF999999),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                            context, AppRoutes.register);
                      },
                      child: Text(
                        "Register",
                        style: TextStyle(
                          color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
