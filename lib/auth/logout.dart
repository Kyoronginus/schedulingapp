import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../routes/app_routes.dart';
import '../services/secure_storage_service.dart';

Future<void> logout(BuildContext context) async {
  try {
    await Amplify.Auth.signOut();

    // Clear stored password and other secure data
    await SecureStorageService.clearAll();

    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.register, (route) => false);

  } catch (e) {
    print('❌ Logout failed: $e');
  }
}
