import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:provider/provider.dart';
import '../routes/app_routes.dart';
import '../services/secure_storage_service.dart';
import '../services/notification_service.dart';
import '../services/profile_picture_service.dart';
import '../providers/group_selection_provider.dart';

Future<void> logout(BuildContext context) async {
  try {
    await _clearGroupProviderData(context);
    await _clearUserSessionData();
    await Amplify.Auth.signOut();
    await SecureStorageService.clearAll();

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
    NotificationService.clearCache();
    await ProfileImageService.clearCurrentUserProfileImages();
    await SecureStorageService.clearCurrentUserData();

    debugPrint('✅ User session data cleared');
  } catch (e) {
    debugPrint('❌ Error clearing user session data: $e');
  }
}

Future<void> _clearGroupProviderData(BuildContext context) async {
  try {
    if (context.mounted) {
      final groupProvider = Provider.of<GroupSelectionProvider>(context, listen: false);
      await groupProvider.clearState();

      groupProvider.reset();
      debugPrint('✅ Group provider data cleared');
    }
  } catch (e) {
    debugPrint('❌ Error clearing group provider data: $e');
  }
}
