import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter/material.dart';
import '../amplifyconfiguration.dart';

Future<void> initAmplify() async {
  try {
    final authPlugin = AmplifyAuthCognito();
    await Amplify.addPlugin(authPlugin);
    await Amplify.configure(amplifyconfig);
    print('✅ Amplify configured');
  } catch (e) {
    print('⚠️ Amplify already configured: $e');
  }
}

Future<void> signUp(String email, String password) async {
  final userAttributes = {
    CognitoUserAttributeKey.email: email,
  };

  final result = await Amplify.Auth.signUp(
    username: email,
    password: password,
    options: CognitoSignUpOptions(userAttributes: userAttributes),
  );

  print('✅ Sign up result: ${result.isSignUpComplete}');
}

Future<void> confirmCode(String email, String code) async {
  final result = await Amplify.Auth.confirmSignUp(
    username: email,
    confirmationCode: code,
  );

  print('✅ Confirm sign up: ${result.isSignUpComplete}');
}

Future<void> login(String email, String password) async {
  final result = await Amplify.Auth.signIn(
    username: email,
    password: password,
  );

  print('✅ Login success: ${result.isSignedIn}');
}

/// Sign in with Google using Amplify Auth
Future<bool> signInWithGoogle(BuildContext context) async {
  try {
    // Start the sign-in process
    final result = await Amplify.Auth.signInWithWebUI(
      provider: AuthProvider.google,
      options: const CognitoSignInWithWebUIOptions(
        isPreferPrivateSession: false,
      ),
    );

    if (result.isSignedIn) {
      print('✅ Google Sign In Success');
      return true;
    } else {
      print('❌ Google Sign In Failed');
      return false;
    }
  } on AmplifyException catch (e) {
    print('❌ Google Sign In Error: ${e.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Google Sign In Error: ${e.message}')),
    );
    return false;
  }
}

/// Sign in with Facebook using Amplify Auth
Future<bool> signInWithFacebook(BuildContext context) async {
  try {
    // Start the sign-in process
    final result = await Amplify.Auth.signInWithWebUI(
      provider: AuthProvider.facebook,
      options: const CognitoSignInWithWebUIOptions(
        isPreferPrivateSession: false,
      ),
    );

    if (result.isSignedIn) {
      print('✅ Facebook Sign In Success');
      return true;
    } else {
      print('❌ Facebook Sign In Failed');
      return false;
    }
  } on AmplifyException catch (e) {
    print('❌ Facebook Sign In Error: ${e.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Facebook Sign In Error: ${e.message}')),
    );
    return false;
  }
}
