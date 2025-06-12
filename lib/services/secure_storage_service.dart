import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

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
