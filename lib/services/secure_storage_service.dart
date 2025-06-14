import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _passwordKey = 'user_password';

  /// Store the user's password securely
  static Future<void> storePassword(String password) async {
    try {
      await _storage.write(key: _passwordKey, value: password);
      debugPrint('✅ Password stored securely: ${password.length} characters');
    } catch (e) {
      debugPrint('❌ Error storing password: $e');
      // Check if it's a MissingPluginException
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('⚠️ Secure storage plugin not properly configured. Please ensure flutter_secure_storage is properly set up for your platform.');
      }
    }
  }

  /// Retrieve the user's password
  static Future<String?> getPassword() async {
    try {
      final password = await _storage.read(key: _passwordKey);
      debugPrint('✅ Password retrieved from secure storage: ${password != null ? "${password.length} characters" : "null"}');
      return password;
    } catch (e) {
      debugPrint('❌ Error retrieving password: $e');
      // Check if it's a MissingPluginException
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('⚠️ Secure storage plugin not properly configured. Please ensure flutter_secure_storage is properly set up for your platform.');
      }
      return null;
    }
  }

  /// Clear the stored password (e.g., on logout)
  static Future<void> clearPassword() async {
    try {
      await _storage.delete(key: _passwordKey);
      debugPrint('✅ Password cleared from secure storage');
    } catch (e) {
      debugPrint('❌ Error clearing password: $e');
    }
  }

  /// Get current user ID for session management
  static Future<String?> getCurrentUserId() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user.userId;
    } catch (e) {
      debugPrint('❌ Error getting current user ID: $e');
      return null;
    }
  }

  /// Store user-specific data with user ID prefix
  static Future<void> storeUserData(String key, String value) async {
    try {
      final userId = await getCurrentUserId();
      if (userId != null) {
        final userSpecificKey = '${userId}_$key';
        await _storage.write(key: userSpecificKey, value: value);
        debugPrint('✅ User-specific data stored: $userSpecificKey');
      }
    } catch (e) {
      debugPrint('❌ Error storing user-specific data: $e');
    }
  }

  /// Retrieve user-specific data with user ID prefix
  static Future<String?> getUserData(String key) async {
    try {
      final userId = await getCurrentUserId();
      if (userId != null) {
        final userSpecificKey = '${userId}_$key';
        return await _storage.read(key: userSpecificKey);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error retrieving user-specific data: $e');
      return null;
    }
  }

  /// Clear all data for current user
  static Future<void> clearCurrentUserData() async {
    try {
      final userId = await getCurrentUserId();
      if (userId != null) {
        final allKeys = await _storage.readAll();
        for (final key in allKeys.keys) {
          if (key.startsWith('${userId}_')) {
            await _storage.delete(key: key);
          }
        }
        debugPrint('✅ Current user data cleared for user: $userId');
      }
    } catch (e) {
      debugPrint('❌ Error clearing current user data: $e');
    }
  }

  /// Clear all stored data
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('✅ All secure storage cleared');
    } catch (e) {
      debugPrint('❌ Error clearing all secure storage: $e');
    }
  }
}
