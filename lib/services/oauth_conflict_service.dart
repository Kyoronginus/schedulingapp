import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

/// Service for handling OAuth authentication UI dialogs and errors
/// Note: Conflict detection is now handled by Lambda triggers
class OAuthConflictService {

  /// Extract email from OAuth user attributes after successful sign-in
  static Future<String?> extractEmailFromOAuthUser() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      
      for (final attr in attributes) {
        if (attr.userAttributeKey == CognitoUserAttributeKey.email) {
          return attr.value;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error extracting email from OAuth user: $e');
      return null;
    }
  }

  /// Show account conflict dialog with detailed information
  static void showAccountConflictDialog(
    BuildContext context,
    Map<String, String> conflictInfo,
    {VoidCallback? onEmailLoginPressed}
  ) {
    final email = conflictInfo['email'] ?? 'your email';
    final existingMethod = conflictInfo['existingMethod'] ?? 'another method';
    final attemptedMethod = conflictInfo['attemptedMethod'] ?? 'this method';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDarkMode = themeProvider.isDarkMode;

        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Text(
                'Account Already Exists',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'An account with the email "$email" already exists.',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.blue[900] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode ? Colors.blue[700]! : Colors.blue[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Existing sign-in method:',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      existingMethod,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.orange[900] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode ? Colors.orange[700]! : Colors.orange[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attempted sign-in method:',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.orange[300] : Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      attemptedMethod,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'To access your account, please use $existingMethod to sign in.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          actions: [
            if (existingMethod.contains('email/password') && onEmailLoginPressed != null)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onEmailLoginPressed();
                },
                icon: const Icon(Icons.email),
                label: const Text('Sign in with Email'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show OAuth configuration error dialog
  static void showOAuthConfigurationError(BuildContext context, String provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDarkMode = themeProvider.isDarkMode;

        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text(
                '$provider Sign-In Unavailable',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$provider sign-in is currently not configured properly.',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alternative options:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Use email/password sign-in',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      '• Contact support for assistance',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show general OAuth error dialog
  static void showOAuthError(BuildContext context, String provider, String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDarkMode = themeProvider.isDarkMode;

        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          title: Text(
            '$provider Sign-In Error',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'An error occurred during sign-in:',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.red[900] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode ? Colors.red[700]! : Colors.red[200]!,
                  ),
                ),
                child: Text(
                  error,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please try again or use email/password sign-in.',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }


}
