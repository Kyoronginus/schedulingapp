import 'package:amplify_flutter/amplify_flutter.dart';

String authErrorMessage(AuthException e) {
  final message = e.message.toLowerCase();

  if (message.contains('user does not exist')) {
    return 'No account found for this email.';
  } else if (message.contains('incorrect username or password')) {
    return 'Incorrect email or password.';
  } else if (message.contains('user is not confirmed')) {
    return 'Please verify your email before logging in.';
  } else if (message.contains('too many failed attempts')) {
    return 'Too many failed attempts. Please try again later.';
  } else if (message.contains('network')) {
    return 'Network error. Please check your connection.';
  }

  return 'Login failed. Please check your credentials and try again.';
}
