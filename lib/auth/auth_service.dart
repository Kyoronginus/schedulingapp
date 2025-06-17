import 'dart:convert';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import '../amplifyconfiguration.dart';
import '../models/User.dart';
import '../services/oauth_conflict_service.dart';
import '../services/refresh_service.dart';
import '../services/secure_storage_service.dart';

// initAmplify, signUp, confirmCode, login functions remain the same
Future<void> initAmplify() async {
  try {
    final authPlugin = AmplifyAuthCognito();
    await Amplify.addPlugin(authPlugin);
    await Amplify.configure(amplifyconfig);
    debugPrint('✅ Amplify configured');
  } on AmplifyAlreadyConfiguredException {
    debugPrint('⚠️ Amplify was already configured.');
  } catch (e) {
    debugPrint('❌ Error configuring Amplify: $e');
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
      throw Exception('Login failed. Please check your credentials.');
    }
    debugPrint('✅ Login success: ${result.isSignedIn}');
    await SecureStorageService.storePassword(password);
  } on AuthException catch (e) {
    throw Exception(e.message);
  }
}

/// This function is the primary way to get the current user's data after login.
Future<User> ensureUserExists() async {
  try {
    debugPrint('🔄 Ensuring user exists by calling getCurrentUser...');
    return await getCurrentUser();
  } catch (e) {
    debugPrint('❌ ensureUserExists failed: $e');
    throw Exception(
      'Could not retrieve user data. Your session may be invalid. Please try logging in again.'
    );
  }
}

/// Fetches the current user's profile from DynamoDB.
/// It correctly uses the user's ID from the session to query the database.
Future<User> getCurrentUser() async {
  try {
    final authUser = await Amplify.Auth.getCurrentUser();
    final idToQuery = authUser.userId;

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
      variables: {'id': idToQuery},
    );

    debugPrint('🔍 AuthService: Sending GraphQL query for user: $idToQuery');
    final response = await Amplify.API.query(request: request).response;

    if (response.hasErrors) {
      throw Exception('GraphQL errors: ${response.errors.map((e) => e.message).join(', ')}');
    }
    if (response.data == null) {
      throw Exception('No data returned from user query');
    }

    final responseJson = jsonDecode(response.data!);
    final userData = responseJson['getUser'];

    if (userData == null) {
      debugPrint('❌ AuthService: User not found in database for ID: $idToQuery');
      throw Exception('User data not found in database.');
    }

    final user = User.fromJson(userData);
    debugPrint('✅ AuthService: Successfully found and created User object for ID: ${user.id}');
    return user;
  } on AuthException catch (e) {
    debugPrint('❌ AuthService: Auth exception: ${e.message}');
    throw Exception('Authentication error: ${e.message}');
  } catch (e) {
    debugPrint('❌ AuthService: Unexpected error in getCurrentUser: $e');
    rethrow;
  }
}

/// Signs in with Google and handles the seamless account linking flow.
Future<bool> signInWithGoogle(BuildContext context) async {
  try {
    final result = await Amplify.Auth.signInWithWebUI(provider: AuthProvider.google);
    if (result.isSignedIn) {
      debugPrint('✅ Google Sign In Success (direct login)');
      await _refreshSessionAfterOAuth();
      return true;
    }
    return false;
  } on AmplifyException catch (e) {
    final String actualErrorMessage = e.message.toLowerCase();
    final bool isAccountLinkingSignal =
        actualErrorMessage.contains('user already exists') || // Common message
        actualErrorMessage.contains('aliasexistsexception') || // Another common one
        actualErrorMessage.contains('already found an entry for username') || // Internal Amplify message
        actualErrorMessage.contains('successfully linked new provider'); // Lambda trigger message

    if (isAccountLinkingSignal) {
      debugPrint('✅ Account linking signal detected. Retrying login...');
      await Future.delayed(const Duration(seconds: 2));

      try {
        // Make sure to use the correct provider for the function
        final result = await Amplify.Auth.signInWithWebUI(provider: AuthProvider.google);
        if (result.isSignedIn) {
          debugPrint('✅ Seamless re-login successful after linking.');
          await _refreshSessionAfterOAuth();
          return true;
        }
      } catch (retryError) {
        debugPrint('❌ Seamless re-login FAILED after linking: $retryError');
        if (context.mounted) {
          _handleOAuthError(context, retryError as AmplifyException, 'Google');
        }
        return false;
      }
    }
    
    if (context.mounted) {
      _handleOAuthError(context, e, 'Google');
    }
    return false;
  }
}

/// Signs in with Facebook and handles the seamless account linking flow.
Future<bool> signInWithFacebook(BuildContext context) async {
  try {
    final result = await Amplify.Auth.signInWithWebUI(provider: AuthProvider.facebook);
    if (result.isSignedIn) {
      debugPrint('✅ Facebook Sign In Success (direct login)');
      await _refreshSessionAfterOAuth();
      return true;
    }
    return false;
  } on AmplifyException catch (e) {
    final String actualErrorMessage = e.message.toLowerCase();
    final bool isAccountLinkingSignal =
        actualErrorMessage.contains('user already exists') || // Common message
        actualErrorMessage.contains('aliasexistsexception') || // Another common one
        actualErrorMessage.contains('already found an entry for username') || // Internal Amplify message
        actualErrorMessage.contains('successfully linked new provider'); // Lambda trigger message

    if (isAccountLinkingSignal) {
      debugPrint('✅ Account linking signal detected. Retrying login...');
      await Future.delayed(const Duration(seconds: 2));

      try {
        // Make sure to use the correct provider for the function
        final result = await Amplify.Auth.signInWithWebUI(provider: AuthProvider.facebook);
        if (result.isSignedIn) {
          debugPrint('✅ Seamless re-login successful after linking.');
          await _refreshSessionAfterOAuth();
          return true;
        }
      } catch (retryError) {
        debugPrint('❌ Seamless re-login FAILED after linking: $retryError');
        if (context.mounted) {
          _handleOAuthError(context, retryError as AmplifyException, 'Facebook');
        }
        return false;
      }
    }
    
    if (context.mounted) {
      _handleOAuthError(context, e, 'Facebook');
    }
    return false;
  }
}

/// Centralized OAuth error handling logic.
void _handleOAuthError(BuildContext context, AmplifyException e, String provider) {
  if (e.message.contains('CognitoOAuthConfig')) {
    OAuthConflictService.showOAuthConfigurationError(context, provider);
    return;
  }
  
  if (e.message.contains('An account with this email already exists')) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$provider Sign In Error: ${e.message}')),
  );
}

/// Refreshes the user session to get updated attributes from Lambda after linking.
/// This function is called by external functions.
Future<void> _refreshSessionAfterOAuth() async {
  try {
    debugPrint('🔄 Starting session refresh after OAuth login/linking...');

    // Wait a brief moment to allow Lambda triggers to complete
    await Future.delayed(const Duration(milliseconds: 500));

    // Force refresh the auth session to get new tokens with updated claims
    final session = await Amplify.Auth.fetchAuthSession(
      options: const FetchAuthSessionOptions(forceRefresh: true),
    );

    if (session.isSignedIn) {
      debugPrint('✅ Auth session refreshed successfully');

      // Get the current user with fresh data
      final user = await Amplify.Auth.getCurrentUser();
      debugPrint('✅ Current user refreshed: ${user.userId}');

      // Fetch user attributes with fresh data
      final attributes = await Amplify.Auth.fetchUserAttributes();
      debugPrint('✅ User attributes refreshed, count: ${attributes.length}');

      // Log the updated attributes for debugging
      for (final attr in attributes) {
        if (attr.userAttributeKey.key == 'name' ||
            attr.userAttributeKey.key == 'custom:primary_user_id' ||
            attr.userAttributeKey.key == 'email') {
          debugPrint('📋 Updated attribute: ${attr.userAttributeKey.key} = ${attr.value}');
        }
      }

      // Notify other parts of the app that profile data may have changed
      RefreshService().notifyProfileChange();

    } else {
      debugPrint('⚠️ Session refresh indicated user is not signed in');
    }

  } catch (e) {
    debugPrint('❌ Error refreshing session after OAuth: $e');
    // Don't throw the error as this is a best-effort operation
    // The user can still proceed, they might just see stale data initially
  }
}
