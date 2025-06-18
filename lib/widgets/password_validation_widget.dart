import 'package:flutter/material.dart';

/// Widget that displays password validation criteria with visual feedback
class PasswordValidationWidget extends StatelessWidget {
  final String password;
  final bool showValidation;

  const PasswordValidationWidget({
    super.key,
    required this.password,
    this.showValidation = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showValidation || password.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasMinLength = PasswordValidator.hasMinLength(password);
    final hasUppercase = PasswordValidator.hasUppercase(password);
    final hasLowercase = PasswordValidator.hasLowercase(password);
    final hasNumber = PasswordValidator.hasNumber(password);

    // Use Padding for positioning, removing the boxed container
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // 2x2 Grid layout for validation items
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildValidationItem('At least 8 characters', hasMinLength),
              ),
              // Add a SizedBox to create a visible gutter between columns
              const SizedBox(width: 16),
              Expanded(
                child: _buildValidationItem('One uppercase letter', hasUppercase),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildValidationItem('One lowercase letter', hasLowercase),
              ),
              // Add a SizedBox to create a visible gutter between columns
              const SizedBox(width: 16),
              Expanded(
                child: _buildValidationItem('One number', hasNumber),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationItem(String text, bool isValid) {
    return Row(
      // Removed MainAxisSize.min to allow Expanded to manage width
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: isValid ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isValid ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
            // Allow text to wrap if needed, preventing it from being cut off
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}


/// Utility class for password validation
class PasswordValidator {
  static String? validatePassword(String? value) {
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

  static bool isPasswordValid(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'\d').hasMatch(password);
  }

  static bool hasMinLength(String password) => password.length >= 8;
  static bool hasUppercase(String password) => RegExp(r'[A-Z]').hasMatch(password);
  static bool hasLowercase(String password) => RegExp(r'[a-z]').hasMatch(password);
  static bool hasNumber(String password) => RegExp(r'\d').hasMatch(password);
}