import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/User.dart';
import '../models/AuthMethod.dart';

/// Service for resolving the primary user ID for any given auth session
/// This ensures all data fetching uses the correct primary user record
/// instead of the current auth provider's user ID
class PrimaryUserService {
  static String? _cachedPrimaryUserId;
  static String? _cachedCurrentAuthUserId;

  /// Get the primary user ID for the current auth session
  /// This method handles account linking by finding the primary user record
  static Future<String> getPrimaryUserId() async {
    try {
      final authUser = await Amplify.Auth.getCurrentUser();
      final currentAuthUserId = authUser.userId;

      // Check cache first
      if (_cachedCurrentAuthUserId == currentAuthUserId && _cachedPrimaryUserId != null) {
        return _cachedPrimaryUserId!;
      }

      debugPrint('🔍 PrimaryUserService: Resolving primary user ID for auth user: $currentAuthUserId');

      // First, try to find if this auth user ID has a direct user record
      final directUser = await _findUserByAuthId(currentAuthUserId);
      if (directUser != null) {
        debugPrint('✅ PrimaryUserService: Found direct user record: ${directUser.id}');
        _cachePrimaryUserId(currentAuthUserId, directUser.id);
        return directUser.id;
      }

      // If no direct record, check if this auth user is linked to another primary user
      final linkedPrimaryUser = await _findLinkedPrimaryUser(currentAuthUserId);
      if (linkedPrimaryUser != null) {
        debugPrint('✅ PrimaryUserService: Found linked primary user: ${linkedPrimaryUser.id}');
        _cachePrimaryUserId(currentAuthUserId, linkedPrimaryUser.id);
        return linkedPrimaryUser.id;
      }

      // If no linked user found, check by email (for OAuth users who might not have records yet)
      final emailBasedUser = await _findUserByEmail();
      if (emailBasedUser != null) {
        debugPrint('✅ PrimaryUserService: Found email-based user: ${emailBasedUser.id}');
        _cachePrimaryUserId(currentAuthUserId, emailBasedUser.id);
        return emailBasedUser.id;
      }

      // If still no user found, return the current auth user ID as fallback
      debugPrint('⚠️ PrimaryUserService: No primary user found, using current auth user ID as fallback');
      _cachePrimaryUserId(currentAuthUserId, currentAuthUserId);
      return currentAuthUserId;

    } catch (e) {
      debugPrint('❌ PrimaryUserService: Error resolving primary user ID: $e');
      // Fallback to current auth user ID
      try {
        final authUser = await Amplify.Auth.getCurrentUser();
        return authUser.userId;
      } catch (authError) {
        debugPrint('❌ PrimaryUserService: Cannot get current auth user: $authError');
        rethrow;
      }
    }
  }

  /// Get the primary user record for the current auth session
  static Future<User?> getPrimaryUser() async {
    try {
      final primaryUserId = await getPrimaryUserId();
      return await _findUserByAuthId(primaryUserId);
    } catch (e) {
      debugPrint('❌ PrimaryUserService: Error getting primary user: $e');
      return null;
    }
  }

  /// Clear the cache (useful when user signs out or switches accounts)
  static void clearCache() {
    _cachedPrimaryUserId = null;
    _cachedCurrentAuthUserId = null;
    debugPrint('🧹 PrimaryUserService: Cache cleared');
  }

  /// Cache the primary user ID for performance
  static void _cachePrimaryUserId(String authUserId, String primaryUserId) {
    _cachedCurrentAuthUserId = authUserId;
    _cachedPrimaryUserId = primaryUserId;
  }

  /// Find a user record by auth user ID
  static Future<User?> _findUserByAuthId(String authUserId) async {
    try {
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
        variables: {'id': authUserId},
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.hasErrors || response.data == null) {
        return null;
      }

      final Map<String, dynamic> responseJson = jsonDecode(response.data!);
      final userData = responseJson['getUser'];
      
      if (userData == null) {
        return null;
      }

      return User.fromJson(userData);
    } catch (e) {
      debugPrint('❌ PrimaryUserService: Error finding user by auth ID: $e');
      return null;
    }
  }

  /// Find the primary user that this auth user ID is linked to
  /// This searches for users where the current auth user ID appears in linkedAuthMethods
  static Future<User?> _findLinkedPrimaryUser(String authUserId) async {
    try {
      // Note: This requires a custom GraphQL query or index
      // For now, we'll search by email as a workaround
      final email = await _getCurrentUserEmail();
      if (email == null) return null;

      return await _findUserByEmailDirect(email);
    } catch (e) {
      debugPrint('❌ PrimaryUserService: Error finding linked primary user: $e');
      return null;
    }
  }

  /// Find user by email from current auth session
  static Future<User?> _findUserByEmail() async {
    try {
      final email = await _getCurrentUserEmail();
      if (email == null) return null;

      return await _findUserByEmailDirect(email);
    } catch (e) {
      debugPrint('❌ PrimaryUserService: Error finding user by email: $e');
      return null;
    }
  }

  /// Get email from current auth session
  static Future<String?> _getCurrentUserEmail() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      for (final attr in attributes) {
        if (attr.userAttributeKey == CognitoUserAttributeKey.email) {
          return attr.value;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ PrimaryUserService: Error getting current user email: $e');
      return null;
    }
  }

  /// Find user by email using GraphQL query
  static Future<User?> _findUserByEmailDirect(String email) async {
    try {
      final request = GraphQLRequest<String>(
        document: '''
          query ListUsersByEmail(\$email: String!) {
            listUsersByEmail(email: \$email) {
              items {
                id
                email
                name
                primaryAuthMethod
                linkedAuthMethods
              }
            }
          }
        ''',
        variables: {'email': email},
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.hasErrors || response.data == null) {
        return null;
      }

      final Map<String, dynamic> responseJson = jsonDecode(response.data!);
      final items = responseJson['listUsersByEmail']['items'] as List?;

      if (items == null || items.isEmpty) {
        return null;
      }

      // Return the first user found (should be unique by email)
      final userData = items.first as Map<String, dynamic>;
      return User.fromJson(userData);
    } catch (e) {
      debugPrint('❌ PrimaryUserService: Error finding user by email direct: $e');
      return null;
    }
  }

  /// Check if the current auth user is the primary user
  static Future<bool> isCurrentUserPrimary() async {
    try {
      final authUser = await Amplify.Auth.getCurrentUser();
      final primaryUserId = await getPrimaryUserId();
      return authUser.userId == primaryUserId;
    } catch (e) {
      debugPrint('❌ PrimaryUserService: Error checking if current user is primary: $e');
      return true; // Default to true to avoid issues
    }
  }

  /// Get auth method mapping for the current session
  /// Returns which auth method was used to sign in
  static Future<String> getCurrentAuthMethod() async {
    try {
      final authUser = await Amplify.Auth.getCurrentUser();
      final primaryUser = await getPrimaryUser();
      
      if (primaryUser == null) {
        return 'Unknown';
      }

      // If current auth user ID matches primary user ID, they're using primary method
      if (authUser.userId == primaryUser.id) {
        return _getAuthMethodDisplayName(primaryUser.primaryAuthMethod);
      }

      // Otherwise, determine which linked method they're using
      // This is a simplified approach - in a full implementation,
      // you might want to store auth session metadata
      return 'Linked Account';
    } catch (e) {
      debugPrint('❌ PrimaryUserService: Error getting current auth method: $e');
      return 'Unknown';
    }
  }

  /// Convert auth method enum to display name
  static String _getAuthMethodDisplayName(AuthMethod authMethod) {
    switch (authMethod) {
      case AuthMethod.EMAIL:
        return 'Email';
      case AuthMethod.GOOGLE:
        return 'Google';
      case AuthMethod.FACEBOOK:
        return 'Facebook';
      default:
        return 'Unknown';
    }
  }
}
