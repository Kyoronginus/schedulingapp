import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../../utils/utils_functions.dart';
import '../../services/secure_storage_service.dart';
import '../../routes/app_routes.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStoredPassword();
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

  Color _getBorderColor(FocusNode focusNode,
      {bool isValid = false, bool hasMismatch = false}) {
    if (focusNode.hasFocus) {
      if (hasMismatch) return Colors.red;
      return isValid ? Colors.green : primaryColor;
    }
    return secondaryColor;
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
    // UI State Calculation
    final currentPasswordHasInput = _currentPasswordController.text.isNotEmpty;
    final currentPasswordMismatch = currentPasswordHasInput &&
        _storedPassword != null &&
        !_currentPasswordMatches;
    final passwordsHaveInput = _newPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty;
    final passwordMismatch = passwordsHaveInput && !_passwordsMatch;

    final currentPasswordBorderColor = _getBorderColor(_currentPasswordFocus,
        isValid: currentPasswordHasInput && _currentPasswordMatches,
        hasMismatch: currentPasswordMismatch);
    final newPasswordBorderColor = _getBorderColor(_newPasswordFocus,
        isValid: passwordsHaveInput && _passwordsMatch,
        hasMismatch: passwordMismatch);
    final confirmPasswordBorderColor = _getBorderColor(_confirmPasswordFocus,
        isValid: passwordsHaveInput && _passwordsMatch,
        hasMismatch: passwordMismatch);
    
    // Mengubah widget terluar menjadi Dialog
    return Dialog(
      alignment: const Alignment(0.0, -0.25), 
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.white, // Latar belakang kartu
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
    const Text(
      "Change Password",
      style: TextStyle(
        fontSize: 24, // Ukuran font sedikit disesuaikan agar rapi
        fontWeight: FontWeight.bold,
        color: Color(0xFF222B45),
      ),
    ),
    // 3. Tombol IconButton sekarang menjadi elemen terakhir
    IconButton(
      onPressed: () => Navigator.pop(context),
      // 4. Ikon diubah menjadi silang (close)
      icon: const Icon(
        Icons.close,
        color: Colors.grey, // Warna dibuat lebih soft
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
                          decoration: InputDecoration(
                            hintText: "Current Password",
                            prefixIcon:  Icon(Icons.lock_outline, color: primaryColor),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (currentPasswordHasInput && _storedPassword != null)
                                  Icon(
                                    _currentPasswordMatches ? Icons.check_circle : Icons.cancel,
                                    color: _currentPasswordMatches ? Colors.green : Colors.red,
                                  ),
                                IconButton(
                                  icon: Icon(
                                    _obscureCurrentPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: primaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscureCurrentPassword = !_obscureCurrentPassword);
                                  },
                                ),
                              ],
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide:  BorderSide(color: secondaryColor, width: 1.5)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: currentPasswordBorderColor, width: 2)),
                          ),
                          validator: _validateCurrentPasswordField,
                        ),
                        if (_currentPasswordInlineError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 16),
                            child: Text(
                              _currentPasswordInlineError!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
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
                      decoration: InputDecoration(
                        hintText: "New Password",
                        prefixIcon:  Icon(Icons.lock, color: primaryColor),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_getNewPasswordMatchIcon() != null) _getNewPasswordMatchIcon()!,
                            IconButton(
                              icon: Icon(
                                _obscureNewPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: primaryColor,
                              ),
                              onPressed: () {
                                setState(() => _obscureNewPassword = !_obscureNewPassword);
                              },
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide:  BorderSide(color: secondaryColor, width: 1.5)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: newPasswordBorderColor, width: 2)),
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
                          decoration: InputDecoration(
                            hintText: "Confirm New Password",
                            prefixIcon:  Icon(Icons.lock, color: primaryColor),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_getNewPasswordMatchIcon() != null) _getNewPasswordMatchIcon()!,
                                IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: primaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                  },
                                ),
                              ],
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide:  BorderSide(color: secondaryColor, width: 2)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: confirmPasswordBorderColor, width: 2)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please confirm your password';
                            if (value != _newPasswordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        if (_confirmPasswordInlineError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 16),
                            child: Text(
                              _confirmPasswordInlineError!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                        child:  Text(
                          "Forgot Password?",
                          style: TextStyle(color: primaryColor,
                        fontWeight: FontWeight.bold,),
                        ),
                      ),
                    ),

                    // Change password button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _validateAndSendVerificationCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Change Password", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
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