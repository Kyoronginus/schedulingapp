import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';
import '../models/User.dart';

/// Service for mapping OAuth Cognito users to primary DynamoDB user records
/// This handles the complexity of account linking where multiple Cognito identities
/// map to a single application user record
class SessionMappingService {
  
  /// Get the primary user ID for the current session
  /// This maps the current Cognito user to the primary DynamoDB user record
  static Future<String> getPrimaryUserId() async {
    try {
      debugPrint('🔍 SessionMappingService: Getting primary user ID');
      
      final currentUser = await Amplify.Auth.getCurrentUser();
      final cognitoUserId = currentUser.userId;
      
      debugPrint('🔍 SessionMappingService: Current Cognito user ID: $cognitoUserId');
      
      // Get user attributes to check for linking information
      final attributes = await Amplify.Auth.fetchUserAttributes();
      
      // Look for custom:primary_user_id attribute set by Lambda triggers
      final primaryUserIdAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey.key == 'custom:primary_user_id',
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.custom('primary_user_id'),
          value: '',
        ),
      );
      
      if (primaryUserIdAttr.value.isNotEmpty) {
        debugPrint('✅ SessionMappingService: Found primary user ID: ${primaryUserIdAttr.value}');
        return primaryUserIdAttr.value;
      }
      
      // If no mapping exists, this Cognito user is the primary account
      debugPrint('✅ SessionMappingService: No mapping found, using Cognito user ID as primary: $cognitoUserId');
      return cognitoUserId;
      
    } catch (e) {
      debugPrint('❌ SessionMappingService: Error getting primary user ID: $e');
      
      // Fallback to current Cognito user ID
      try {
        final currentUser = await Amplify.Auth.getCurrentUser();
        return currentUser.userId;
      } catch (fallbackError) {
        debugPrint('❌ SessionMappingService: Fallback also failed: $fallbackError');
        rethrow;
      }
    }
  }
  
  /// Get the current user record using session mapping
  /// This ensures we always get the primary user record regardless of which
  /// linked authentication method was used to sign in
  static Future<User> getCurrentUser() async {
    try {
      debugPrint('🔍 SessionMappingService: Getting current user with session mapping');
      
      final primaryUserId = await getPrimaryUserId();
      
      // Query the user data using the primary user ID
      final request = GraphQLRequest<String>(
        document: '''
          query GetUser(\$id: ID!) {
            getUser(id: \$id) {
              id
              email
              name
              primaryAuthMethod
              linkedAuthMethods
              profilePictureUrl
            }
          }
        ''',
        variables: {'id': primaryUserId},
      );
      
      debugPrint('🔍 SessionMappingService: Querying user with primary ID: $primaryUserId');
      
      final response = await Amplify.API.query(request: request).response;
      
      if (response.hasErrors) {
        debugPrint('❌ SessionMappingService: GraphQL errors: ${response.errors}');
        throw Exception('Failed to fetch user: ${response.errors}');
      }
      
      if (response.data == null) {
        debugPrint('❌ SessionMappingService: No data returned');
        throw Exception('No user data returned');
      }
      
      final responseJson = jsonDecode(response.data!);
      final userData = responseJson['getUser'];
      
      if (userData == null) {
        debugPrint('❌ SessionMappingService: User not found with ID: $primaryUserId');
        throw Exception('User not found');
      }
      
      final user = User.fromJson(userData);
      debugPrint('✅ SessionMappingService: Successfully retrieved user: ${user.email}');
      return user;
      
    } catch (e) {
      debugPrint('❌ SessionMappingService: Error getting current user: $e');
      rethrow;
    }
  }
  
  /// Check if the current session is for a linked account
  /// Returns true if this Cognito user is linked to a different primary account
  static Future<bool> isLinkedAccount() async {
    try {
      final currentUser = await Amplify.Auth.getCurrentUser();
      final cognitoUserId = currentUser.userId;
      final primaryUserId = await getPrimaryUserId();
      
      final isLinked = cognitoUserId != primaryUserId;
      debugPrint('🔍 SessionMappingService: Is linked account: $isLinked (Cognito: $cognitoUserId, Primary: $primaryUserId)');
      return isLinked;
      
    } catch (e) {
      debugPrint('❌ SessionMappingService: Error checking if linked account: $e');
      return false;
    }
  }
  
  /// Get authentication method information for the current session
  static Future<SessionAuthInfo> getSessionAuthInfo() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      
      // Get auth provider from custom attribute
      final authProviderAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey.key == 'custom:auth_provider',
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.custom('auth_provider'),
          value: 'email',
        ),
      );
      
      // Check if this is a linked account
      final linkedAccountAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey.key == 'custom:linked_account',
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.custom('linked_account'),
          value: 'false',
        ),
      );
      
      // Check if this is a primary account
      final primaryAccountAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey.key == 'custom:primary_account',
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.custom('primary_account'),
          value: 'false',
        ),
      );
      
      return SessionAuthInfo(
        authProvider: authProviderAttr.value,
        isLinkedAccount: linkedAccountAttr.value == 'true',
        isPrimaryAccount: primaryAccountAttr.value == 'true',
      );
      
    } catch (e) {
      debugPrint('❌ SessionMappingService: Error getting session auth info: $e');
      return SessionAuthInfo(
        authProvider: 'email',
        isLinkedAccount: false,
        isPrimaryAccount: true,
      );
    }
  }
  
  /// Clear session mapping cache (useful for testing or troubleshooting)
  static Future<void> clearSessionCache() async {
    try {
      debugPrint('🔄 SessionMappingService: Clearing session cache');
      // This is a placeholder for any caching mechanisms we might add later
      debugPrint('✅ SessionMappingService: Session cache cleared');
    } catch (e) {
      debugPrint('❌ SessionMappingService: Error clearing session cache: $e');
    }
  }
}

/// Information about the current authentication session
class SessionAuthInfo {
  final String authProvider;
  final bool isLinkedAccount;
  final bool isPrimaryAccount;
  
  const SessionAuthInfo({
    required this.authProvider,
    required this.isLinkedAccount,
    required this.isPrimaryAccount,
  });
  
  @override
  String toString() {
    return 'SessionAuthInfo(provider: $authProvider, linked: $isLinkedAccount, primary: $isPrimaryAccount)';
  }
}
