import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../routes/app_routes.dart';
import '../services/secure_storage_service.dart';
import '../services/notification_service.dart';
import '../services/profile_picture_service.dart';

Future<void> logout(BuildContext context) async {
  try {
    // Clear user-specific data before signing out
    await _clearUserSessionData();

    // Sign out from Amplify
    await Amplify.Auth.signOut();

    // Clear all remaining secure storage
    await SecureStorageService.clearAll();

    // Check if context is still mounted before navigation
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.register, (route) => false);
    }

  } catch (e) {
    debugPrint('❌ Logout failed: $e');
  }
}

/// Clear all user-specific session data
Future<void> _clearUserSessionData() async {
  try {
    // Clear notification cache
    NotificationService.clearCache();

    // Clear profile images for current user
    await ProfileImageService.clearCurrentUserProfileImages();

    // Clear current user data from secure storage
    await SecureStorageService.clearCurrentUserData();

    debugPrint('✅ User session data cleared');
  } catch (e) {
    debugPrint('❌ Error clearing user session data: $e');
  }
}
