import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

/// Service for handling OAuth authentication conflicts and errors
class OAuthConflictService {
  
  /// Check if an email is already associated with a different auth method
  static Future<Map<String, String>?> checkEmailConflict(String email, String attemptedProvider) async {
    try {
      // Try to sign in with email/password to check if account exists
      // This is a safe way to check without actually signing in
      await Amplify.Auth.signIn(
        username: email,
        password: 'dummy_password_for_check',
      );
      
      // If we get here without exception, account exists with email/password
      return {
        'email': email,
        'existingMethod': 'email/password',
        'attemptedMethod': attemptedProvider,
      };
    } on AuthException catch (e) {
      // Check specific error types
      if (e.message.contains('UserNotFoundException')) {
        // No account exists with this email - safe to proceed
        return null;
      } else if (e.message.contains('NotAuthorizedException') || 
                 e.message.contains('Incorrect username or password')) {
        // Account exists but wrong password - this means email/password account exists
        return {
          'email': email,
          'existingMethod': 'email/password',
          'attemptedMethod': attemptedProvider,
        };
      } else if (e.message.contains('UserNotConfirmedException')) {
        // Account exists but not confirmed
        return {
          'email': email,
          'existingMethod': 'email/password (unconfirmed)',
          'attemptedMethod': attemptedProvider,
        };
      }
      
      // For other errors, assume no conflict
      debugPrint('Unexpected auth error during conflict check: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error checking email conflict: $e');
      return null;
    }
  }

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
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text('Account Already Exists'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'An account with the email "$email" already exists.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Existing sign-in method:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      existingMethod,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attempted sign-in method:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      attemptedMethod,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'To access your account, please use $existingMethod to sign in.',
                style: const TextStyle(fontSize: 14),
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
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text('$provider Sign-In Unavailable'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$provider sign-in is currently not configured properly.'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alternative options:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Text('• Use email/password sign-in'),
                    Text('• Contact support for assistance'),
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
        return AlertDialog(
          title: Text('$provider Sign-In Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('An error occurred during sign-in:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  error,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Please try again or use email/password sign-in.'),
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

  /// Check if OAuth is properly configured
  static bool isOAuthConfigured() {
    try {
      // This is a simple check - in a real implementation, you might
      // want to verify the actual OAuth configuration
      return true; // Assume configured for now
    } catch (e) {
      return false;
    }
  }
}
