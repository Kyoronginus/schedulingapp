import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../routes/app_routes.dart';

Future<void> logout(BuildContext context) async {
  try {
    await Amplify.Auth.signOut();
    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.home, (route) => false);
  } catch (e) {
    print('❌ Logout failed: $e');
  }
}
