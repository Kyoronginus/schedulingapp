import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
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
