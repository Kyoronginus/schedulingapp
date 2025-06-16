import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter/material.dart';
import '../amplifyconfiguration.dart';
import '../models/User.dart';
import '../services/secure_storage_service.dart';
import '../services/oauth_conflict_service.dart';

import '../services/session_mapping_service.dart';
import 'dart:convert';

Future<void> initAmplify() async {
  try {
    final authPlugin = AmplifyAuthCognito();
    await Amplify.addPlugin(authPlugin);
    await Amplify.configure(amplifyconfig);
    debugPrint('✅ Amplify configured');
  } catch (e) {
    debugPrint('⚠️ Amplify already configured: $e');
  }
}

Future<void> signUp(String email, String password) async {
  final userAttributes = {CognitoUserAttributeKey.email: email};

  final result = await Amplify.Auth.signUp(
    username: email,
    password: password,
    options: SignUpOptions(userAttributes: userAttributes),
  );

  debugPrint('✅ Sign up result: ${result.isSignUpComplete}');
}

Future<void> confirmCode(String email, String code) async {
  final result = await Amplify.Auth.confirmSignUp(
    username: email,
    confirmationCode: code,
  );

  debugPrint('✅ Confirm sign up: ${result.isSignUpComplete}');
}

Future<void> login(String email, String password) async {
  try {
    final result = await Amplify.Auth.signIn(
      username: email,
      password: password,
    );

    if (!result.isSignedIn) {
      final nextStep = result.nextStep.signInStep;
      if (nextStep == AuthSignInStep.confirmSignUp) {
        throw Exception(
          'Your account is not confirmed. Please verify your email.',
        );
      } else {
        throw Exception(
          'Login failed. Make sure your email and password are correct.',
        );
      }
    }

    debugPrint('✅ Login success: ${result.isSignedIn}');

    // Store the password securely for display purposes
    await SecureStorageService.storePassword(password);
  } on AuthException catch (e) {
    throw Exception(e.message);
  }
}

/// Gets the current user using session mapping (Lambda triggers handle user creation)
Future<User> ensureUserExists() async {
  try {
    debugPrint('🔍 AuthService: Getting user with session mapping...');

    // Use session mapping service to get the current user
    // This handles linked accounts and maps to the primary user record
    return await SessionMappingService.getCurrentUser();
  } catch (e) {
    debugPrint('❌ AuthService: Error getting user with session mapping: $e');

    // If session mapping fails, try the legacy getCurrentUser method as fallback
    try {
      debugPrint('🔄 AuthService: Falling back to legacy getCurrentUser...');
      return await getCurrentUser();
    } catch (fallbackError) {
      debugPrint('❌ AuthService: Legacy fallback also failed: $fallbackError');

      // If both methods fail, the user record should have been created by Lambda triggers
      // This suggests a configuration issue or the triggers aren't working properly
      throw Exception(
        'User record not found. This may indicate an issue with account setup. '
        'Please try signing out and signing in again, or contact support if the problem persists.'
      );
    }
  }
}

Future<User> getCurrentUser() async {
  try {
    // Get the authenticated user
    final authUser = await Amplify.Auth.getCurrentUser();
    debugPrint('🔍 AuthService: Got auth user with ID: ${authUser.userId}');

    // Query the user data from the API
    final request = GraphQLRequest<String>(
      document: '''
        query GetUser(\$id: ID!) {
          getUser(id: \$id) {
            id
            email
            name
            primaryAuthMethod
            linkedAuthMethods
          }
        }
      ''',
      variables: {'id': authUser.userId},
    );

    debugPrint(
      '🔍 AuthService: Sending GraphQL query for user: ${authUser.userId}',
    );
    final response = await Amplify.API.query(request: request).response;

    // Check for GraphQL errors
    if (response.hasErrors) {
      debugPrint('❌ AuthService: GraphQL errors: ${response.errors}');
      throw Exception(
        'GraphQL errors: ${response.errors.map((e) => e.message).join(', ')}',
      );
    }

    // Check if response data exists
    if (response.data == null) {
      debugPrint('❌ AuthService: No data returned from GraphQL query');
      throw Exception('No data returned from user query');
    }

    // Parse the JSON response
    final Map<String, dynamic> responseJson;
    try {
      responseJson = jsonDecode(response.data!);
      debugPrint('🔍 AuthService: Parsed response JSON: $responseJson');
    } catch (e) {
      debugPrint('❌ AuthService: Failed to parse JSON: $e');
      throw Exception('Failed to parse response JSON: $e');
    }

    // Check if getUser data exists
    final userData = responseJson['getUser'];
    if (userData == null) {
      debugPrint(
        '❌ AuthService: User not found in database for ID: ${authUser.userId}',
      );
      throw Exception(
        'User not found in database. Please complete your profile setup.',
      );
    }

    // Create and return User object
    final user = User.fromJson(userData);
    debugPrint(
      '✅ AuthService: Successfully created User object: ${user.toString()}',
    );
    return user;
  } on AuthException catch (e) {
    debugPrint('❌ AuthService: Auth exception: ${e.message}');
    throw Exception('Authentication error: ${e.message}');
  } catch (e) {
    debugPrint('❌ AuthService: Unexpected error: $e');
    rethrow;
  }
}

/// Sign in with Google using Amplify Auth
Future<bool> signInWithGoogle(BuildContext context) async {
  try {
    // Start the sign-in process
    final result = await Amplify.Auth.signInWithWebUI(
      provider: AuthProvider.google,
      options: const SignInWithWebUIOptions(
        pluginOptions: CognitoSignInWithWebUIPluginOptions(
          isPreferPrivateSession: false,
        ),
      ),
    );

    if (result.isSignedIn) {
      debugPrint('✅ Google Sign In Success');

      // Lambda triggers handle all account linking and user creation automatically
      debugPrint('ℹ️ Account linking and user creation handled by Lambda triggers');

      return true;
    } else {
      debugPrint('❌ Google Sign In Failed');
      return false;
    }
  } on AmplifyException catch (e) {
    debugPrint('❌ Google Sign In Error: ${e.message}');

    if (!context.mounted) return false;

    // Handle specific OAuth configuration errors
    if (e.message.contains('CognitoOAuthConfig') ||
        e.message.contains('OAuth') ||
        e.message.contains('identity provider')) {
      OAuthConflictService.showOAuthConfigurationError(context, 'Google');
      return false;
    }

    // Handle account linking conflicts
    if (e.message.contains('already exists') ||
        e.message.contains('linked to another account')) {
      final email = await OAuthConflictService.extractEmailFromOAuthUser();
      if (email != null && context.mounted) {
        OAuthConflictService.showAccountConflictDialog(context, {
          'email': email,
          'existingMethod': 'email/password',
          'attemptedMethod': 'Google',
        });
      }
      return false;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign In Error: ${e.message}')),
      );
    }
    return false;
  }
}

/// Sign in with Facebook using Amplify Auth
Future<bool> signInWithFacebook(BuildContext context) async {
  try {
    // Start the sign-in process
    final result = await Amplify.Auth.signInWithWebUI(
      provider: AuthProvider.facebook,
      options: const SignInWithWebUIOptions(
        pluginOptions: CognitoSignInWithWebUIPluginOptions(
          isPreferPrivateSession: false,
        ),
      ),
    );

    if (result.isSignedIn) {
      debugPrint('✅ Facebook Sign In Success');

      // Lambda triggers handle all account linking and user creation automatically
      debugPrint('ℹ️ Account linking and user creation handled by Lambda triggers');

      return true;
    } else {
      debugPrint('❌ Facebook Sign In Failed');
      return false;
    }
  } on AmplifyException catch (e) {
    debugPrint('❌ Facebook Sign In Error: ${e.message}');

    if (!context.mounted) return false;

    // Handle specific OAuth configuration errors
    if (e.message.contains('CognitoOAuthConfig') ||
        e.message.contains('OAuth') ||
        e.message.contains('identity provider')) {
      OAuthConflictService.showOAuthConfigurationError(context, 'Facebook');
      return false;
    }

    // Handle account linking conflicts
    if (e.message.contains('already exists') ||
        e.message.contains('linked to another account')) {
      final email = await OAuthConflictService.extractEmailFromOAuthUser();
      if (email != null && context.mounted) {
        OAuthConflictService.showAccountConflictDialog(context, {
          'email': email,
          'existingMethod': 'email/password',
          'attemptedMethod': 'Facebook',
        });
      }
      return false;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Facebook Sign In Error: ${e.message}')),
      );
    }
    return false;
  }
}
