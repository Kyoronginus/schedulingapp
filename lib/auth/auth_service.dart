import 'dart:convert';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import '../amplifyconfiguration.dart';
import '../models/User.dart';
import '../routes/app_routes.dart';
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

Future<User> ensureUserExists() async {
  try {
    debugPrint('🔄 AuthService: Fetching user data with getCurrentUser...');
    return await getCurrentUser();
  } catch (fallbackError) {
    debugPrint('❌ AuthService: Data fetch failed: $fallbackError');


    throw Exception(
      'User record not found. This may indicate an issue with account setup. '
    );
  }
}

Future<User> getCurrentUser() async {
  try {
    // This call is now simpler because we don't need to check custom attributes.
    // The session will always be correct for the primary user after a successful login.
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
      throw Exception(
          'GraphQL errors: ${response.errors.map((e) => e.message).join(', ')}');
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

/// Signs in with Google and correctly handles the account linking flow.
Future<bool> signInWithGoogle(BuildContext context) async {
  try {
    final result = await Amplify.Auth.signInWithWebUI(provider: AuthProvider.google);
    if (result.isSignedIn) {
      debugPrint('✅ Google Sign In Success (direct login)');
      RefreshService().notifyProfileChange();
      return true;
    }
    return false;
  } on AmplifyException catch (e) {
    debugPrint('❌ Google Sign In returned an exception: ${e.message}');
    
    // --- DEFINITIVE SOLUTION FOR SEAMLESS LINKING ---
    // If we catch our custom "success error" from the PreSignUp Lambda...
    if (e.message.contains('Successfully linked new provider to existing account')) {
      debugPrint('✅ Caught linking success signal. Re-initiating sign-in to establish session...');
      try {
        // ...the accounts are now linked. We immediately try to sign in again.
        // This second attempt will succeed seamlessly without a user pop-up,
        // as the browser session is already established.
        final result = await Amplify.Auth.signInWithWebUI(provider: AuthProvider.google);
        if (result.isSignedIn) {
          debugPrint('✅ Seamless re-login successful after linking.');
          RefreshService().notifyProfileChange();
          return true;
        }
      } catch (retryError) {
        // If this second sign-in fails, it's a real, unexpected error.
        debugPrint('❌ Seamless re-login FAILED after linking: $retryError');
        if (context.mounted) {
           _handleOAuthError(context, retryError as AmplifyException, 'Google');
        }
        return false;
      }
    }

    // --- Standard Error Handling for all other cases ---
    if (context.mounted) {
      _handleOAuthError(context, e, 'Google');
    }
    return false;
  }
}

/// Signs in with Facebook and correctly handles the account linking flow.
Future<bool> signInWithFacebook(BuildContext context) async {
  try {
    final result = await Amplify.Auth.signInWithWebUI(provider: AuthProvider.facebook);
    if (result.isSignedIn) {
      debugPrint('✅ Facebook Sign In Success (direct login)');
      RefreshService().notifyProfileChange();
      return true;
    }
    return false;
  } on AmplifyException catch (e) {
    debugPrint('❌ Facebook Sign In returned an exception: ${e.message}');
    
    if (e.message.contains('Successfully linked new provider to existing account')) {
      debugPrint('✅ Caught linking success signal. Showing user-friendly notification...');

      // Show user-friendly notification instead of error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account linking successful. Please log in again to access your account.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Wait 2 seconds before redirecting
        await Future.delayed(const Duration(seconds: 2));

        // Automatically redirect to login page (check mounted again after async gap)
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      }

      // Return false to prevent further navigation in the calling code
      return false;
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
