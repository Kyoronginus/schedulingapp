import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../../utils/utils_functions.dart';
import '../password/forgot_password_screen.dart';
import '../../routes/app_routes.dart';
import '../../widgets/exception_message.dart';
import '../../widgets/keyboard_aware_scaffold.dart';
import '../../providers/group_selection_provider.dart';
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

      final groupProvider = Provider.of<GroupSelectionProvider>(context, listen: false);
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
    final inputDecorationTheme = InputDecoration(
      // Gaya untuk hint dan label saat tidak aktif
      hintStyle: const TextStyle(color: Color(0xFF999999)),
      labelStyle: const TextStyle(color: Color(0xFF999999)),

      // Gaya untuk border saat tidak aktif
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: secondaryColor, width: 1.5),
      ),

      // Gaya untuk border saat aktif (di-klik)
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
    );
    return KeyboardAwareScaffold(
      backgroundColor: const Color(0XFFF2F2F2),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 96),
          // Content
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  // Warna bayangan dibuat sedikit transparan
                  color: Colors.black.withValues(alpha: 0.2),
                  // Seberapa menyebar bayangannya
                  spreadRadius: 2,
                  // Seberapa kabur bayangannya
                  blurRadius: 8,
                  // Posisi bayangan (horizontal, vertikal)
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo or app icon
                const Text("Login to your Account",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222B45),
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
                        color: primaryColor,
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
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: primaryColor)
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
                const Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Color(0xFFCACACA),
                        thickness: 1.5,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "OR",
                        style: TextStyle(
                          color: Color(0xFFCACACA),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Color(0xFFCACACA),
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
                  backgroundColor: Colors.white,
                  textColor: Colors.black87,
                ), // Register link
                const SizedBox(height: 24),
                _buildSocialButton(
                  icon: SvgPicture.asset(
                    'assets/icons/facebook-icon.svg',
                  ),
                  text: "Continue with Facebook",
                  onPressed: _handleFacebookSignIn,
                  backgroundColor: Colors.white,
                  textColor: Colors.black,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(color: Color(0xFF999999)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                            context, AppRoutes.register);
                      },
                      child: Text(
                        "Register",
                        style: TextStyle(
                          color: primaryColor,
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
            color: secondaryColor, // Warna garis tepi (abu-abu muda)
            width: 1.5, // Ketebalan garis tepi
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
              style: const TextStyle(fontSize: 16, color: Color(0xFF999999)),
            ),
          ],
        ),
      ),
    );
  }
}
