import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:provider/provider.dart';
import '../../utils/utils_functions.dart';
import '../../services/secure_storage_service.dart';
import '../../services/auth_method_service.dart';
import '../../routes/app_routes.dart';
import '../../widgets/password_validation_widget.dart';
import '../../theme/theme_provider.dart';
import 'password_verification_screen.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
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

  // OAuth detection
  bool _isOAuthUser = false;

  @override
  void initState() {
    super.initState();
    _loadStoredPassword();
    _detectOAuthUser();
    _currentPasswordController.addListener(_validateCurrentPassword);
    _newPasswordController.addListener(_validateMatchingPasswords);
    _confirmPasswordController.addListener(_validateMatchingPasswords);
    _currentPasswordFocus.addListener(() => setState(() {}));
    _newPasswordFocus.addListener(() => setState(() {}));
    _confirmPasswordFocus.addListener(() => setState(() {}));
  }

  Future<void> _loadStoredPassword() async {
    try {
      _storedPassword = await SecureStorageService.getPassword();
      if (_currentPasswordController.text.isNotEmpty) {
        _validateCurrentPassword();
      }
    } catch (e) {
      debugPrint('Error loading stored password: $e');
    }
  }

  Future<void> _detectOAuthUser() async {
    try {
      final isOAuth = await AuthMethodService.isOAuthOnlyUser();
      if (mounted) {
        setState(() {
          _isOAuthUser = isOAuth;
        });
      }
    } catch (e) {
      debugPrint('Error detecting OAuth user: $e');
    }
  }

  void _showOAuthPasswordChangeDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Password Change Not Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your account is linked to an external provider (Google or Facebook). To change your password, please:',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Go to your provider\'s website:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Google: myaccount.google.com',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    Text(
                      '• Facebook: facebook.com/settings',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '2. Navigate to Security settings',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '3. Change your password there',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The new password will automatically apply to this app.',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Got it',
                style: TextStyle(
                  color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _validateCurrentPassword() {
    setState(() {
      if (_currentPasswordController.text.isNotEmpty &&
          _storedPassword != null) {
        _currentPasswordMatches =
            _currentPasswordController.text == _storedPassword;
        _currentPasswordInlineError =
            _currentPasswordMatches ? null : 'The password input is incorrect.';
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
    return null;
  }

  Color _getBorderColor(
    FocusNode focusNode, {
    bool isValid = false,
    bool hasMismatch = false,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    if (focusNode.hasFocus) {
      if (hasMismatch) return Colors.red;
      return isValid ? Colors.green : (isDarkMode ? const Color(0xFF4CAF50) : primaryColor);
    }
    return isDarkMode ? Colors.grey.shade600 : secondaryColor;
  }

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
    // Check if user is OAuth user first
    if (_isOAuthUser) {
      _showOAuthPasswordChangeDialog();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_currentPasswordMatches) {
      setState(() {
        _errorMessage = 'Current password is incorrect';
      });
      return;
    }

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
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final emailAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey == CognitoUserAttributeKey.email,
        orElse: () => throw Exception('Email not found in user attributes'),
      );
      final email = emailAttr.value;

      await Amplify.Auth.resetPassword(username: email);

      if (mounted) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => PasswordVerificationScreen(
              email: email,
              newPassword: _newPasswordController.text,
              mode: PasswordResetMode.changePassword,
            ),
          ),
        );
        if (result == true) {
          if (mounted) Navigator.of(context).pop(true);
        }
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // UI State Calculation
    final currentPasswordHasInput = _currentPasswordController.text.isNotEmpty;
    final currentPasswordMismatch = currentPasswordHasInput &&
        _storedPassword != null &&
        !_currentPasswordMatches;
    final passwordsHaveInput = _newPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty;
    final passwordMismatch = passwordsHaveInput && !_passwordsMatch;

    final currentPasswordBorderColor = _getBorderColor(
      _currentPasswordFocus,
      isValid: currentPasswordHasInput && _currentPasswordMatches,
      hasMismatch: currentPasswordMismatch,
    );
    final newPasswordBorderColor = _getBorderColor(
      _newPasswordFocus,
      isValid: passwordsHaveInput && _passwordsMatch,
      hasMismatch: passwordMismatch,
    );
    final confirmPasswordBorderColor = _getBorderColor(
      _confirmPasswordFocus,
      isValid: passwordsHaveInput && _passwordsMatch,
      hasMismatch: passwordMismatch,
    );

    // Mengubah widget terluar menjadi Dialog
    return Dialog(
      alignment: const Alignment(0.0, -0.25),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white, // Latar belakang kartu
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                autovalidateMode: _hasAttemptedSubmit
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min, // Penting untuk dialog
                  children: [
                    // Header dengan tombol kembali
                    Row(
                      // 1. Mengatur agar elemen pertama menempel di kiri, dan elemen terakhir di kanan
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 2. Teks judul sekarang menjadi elemen pertama
                        Text(
                          "Change Password",
                          style: TextStyle(
                            fontSize:
                                24, // Ukuran font sedikit disesuaikan agar rapi
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : const Color(0xFF222B45),
                          ),
                        ),
                        // 3. Tombol IconButton sekarang menjadi elemen terakhir
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          // 4. Ikon diubah menjadi silang (close)
                          icon: Icon(
                            Icons.close,
                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey, // Warna dibuat lebih soft
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Current password field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          focusNode: _currentPasswordFocus,
                          controller: _currentPasswordController,
                          obscureText: _obscureCurrentPassword,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: "Current Password",
                            hintStyle: TextStyle(
                              color: isDarkMode ? Colors.white54 : Colors.grey,
                            ),
                            fillColor: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade50,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                            ),
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
                                    color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _obscureCurrentPassword =
                                          !_obscureCurrentPassword,
                                    );
                                  },
                                ),
                              ],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: isDarkMode ? Colors.grey.shade600 : secondaryColor,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: currentPasswordBorderColor,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: _validateCurrentPasswordField,
                        ),
                        if (_currentPasswordInlineError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 16),
                            child: Text(
                              _currentPasswordInlineError!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // New password field
                    TextFormField(
                      focusNode: _newPasswordFocus,
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: "New Password",
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.grey,
                        ),
                        fillColor: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade50,
                        filled: true,
                        prefixIcon: Icon(
                          Icons.lock,
                          color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                        ),
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
                                color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscureNewPassword =
                                      !_obscureNewPassword,
                                );
                              },
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: isDarkMode ? Colors.grey.shade600 : secondaryColor,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: newPasswordBorderColor,
                            width: 2,
                          ),
                        ),
                      ),
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
                          obscureText: _obscureConfirmPassword,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: "Confirm New Password",
                            hintStyle: TextStyle(
                              color: isDarkMode ? Colors.white54 : Colors.grey,
                            ),
                            fillColor: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade50,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.lock,
                              color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                            ),
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
                                    color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    );
                                  },
                                ),
                              ],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: isDarkMode ? Colors.grey.shade600 : secondaryColor,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: confirmPasswordBorderColor,
                                width: 2,
                              ),
                            ),
                          ),
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
                            padding: const EdgeInsets.only(top: 6, left: 16),
                            child: Text(
                              _confirmPasswordInlineError!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Password validation criteria (below confirm password)
                    PasswordValidationWidget(
                      password: _newPasswordController.text,
                      showValidation: _newPasswordController.text.isNotEmpty,
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isOAuthUser
                            ? null
                            : () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.forgotPassword,
                                ),
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: _isOAuthUser
                                ? Colors.grey.withValues(alpha: 0.5)
                                : (isDarkMode ? const Color(0xFF4CAF50) : primaryColor),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Change password button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : _validateAndSendVerificationCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Change Password",
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
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
