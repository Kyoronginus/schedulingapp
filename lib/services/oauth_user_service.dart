import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/User.dart';
import '../models/AuthMethod.dart';
import '../auth/auth_service.dart';
import '../services/auth_method_service.dart';

/// Centralized service for handling OAuth user data fetching with fallback logic
/// This service provides consistent user data retrieval across all screens
class OAuthUserService {
  
  /// Fetches user data with OAuth-aware fallback logic
  /// First tries to get user from DynamoDB, then falls back to Cognito attributes
  static Future<UserData> fetchUserData() async {
    try {
      // Try to get user from DynamoDB first
      final userData = await ensureUserExists();
      debugPrint('✅ OAuthUserService: Got user data from DynamoDB: ${userData.name}');
      
      return UserData(
        id: userData.id,
        name: userData.name,
        email: userData.email,
        authProvider: AuthMethodService.getAuthMethodDisplayName(userData.primaryAuthMethod),
        source: UserDataSource.dynamodb,
      );
    } catch (e) {
      debugPrint('⚠️ OAuthUserService: Could not get user from DynamoDB: $e');
      
      // Fall back to Cognito attributes for OAuth users
      return await _fetchFromCognitoAttributes();
    }
  }

  /// Fetches user data specifically from Cognito attributes
  /// Used as fallback for OAuth users who may not have DynamoDB records
  static Future<UserData> _fetchFromCognitoAttributes() async {
    try {
      // Get current user and attributes
      final authUser = await Amplify.Auth.getCurrentUser();
      final attributes = await Amplify.Auth.fetchUserAttributes();
      
      // Extract email
      final emailAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey == CognitoUserAttributeKey.email,
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.email,
          value: '',
        ),
      );
      
      // Try to get name from Cognito attributes for OAuth users
      String? cognitoName;
      try {
        final nameAttr = attributes.firstWhere(
          (attr) => attr.userAttributeKey == CognitoUserAttributeKey.name,
          orElse: () => const AuthUserAttribute(
            userAttributeKey: CognitoUserAttributeKey.name,
            value: '',
          ),
        );
        cognitoName = nameAttr.value.isNotEmpty ? nameAttr.value : null;
      } catch (nameError) {
        debugPrint('⚠️ OAuthUserService: Could not get name from Cognito: $nameError');
      }
      
      // Detect authentication method
      String authProvider;
      try {
        final currentAuthMethod = await AuthMethodService.detectCurrentAuthMethod();
        authProvider = AuthMethodService.getAuthMethodDisplayName(currentAuthMethod);
      } catch (authError) {
        debugPrint('⚠️ OAuthUserService: Could not detect auth method: $authError');
        authProvider = 'Email'; // Default fallback
      }
      
      final email = emailAttr.value;
      final name = cognitoName ?? email.split('@')[0]; // Use email prefix as fallback
      
      debugPrint('✅ OAuthUserService: Got user data from Cognito: $name ($authProvider)');
      
      return UserData(
        id: authUser.userId,
        name: name,
        email: email,
        authProvider: authProvider,
        source: UserDataSource.cognito,
      );
    } catch (e) {
      debugPrint('❌ OAuthUserService: Error fetching from Cognito: $e');
      rethrow;
    }
  }

  /// Fetches user data by ID with OAuth-aware fallback
  /// Used when you need to get data for a specific user (e.g., in member lists)
  static Future<UserData?> fetchUserDataById(String userId) async {
    try {
      // Try to get user from DynamoDB first
      final user = await getCurrentUser();
      if (user.id == userId) {
        return UserData(
          id: user.id,
          name: user.name,
          email: user.email,
          authProvider: AuthMethodService.getAuthMethodDisplayName(user.primaryAuthMethod),
          source: UserDataSource.dynamodb,
        );
      }
      
      // For other users, we can only get what's in DynamoDB
      // This is a limitation - we can't access other users' Cognito attributes
      return null;
    } catch (e) {
      debugPrint('⚠️ OAuthUserService: Could not get user $userId from DynamoDB: $e');
      return null;
    }
  }

  /// Creates a User object with OAuth-aware data
  /// Used when you need to create a User model object
  static Future<User> createUserObject() async {
    final userData = await fetchUserData();
    
    // Convert auth provider back to AuthMethod enum
    AuthMethod authMethod;
    switch (userData.authProvider.toLowerCase()) {
      case 'google':
        authMethod = AuthMethod.GOOGLE;
        break;
      case 'facebook':
        authMethod = AuthMethod.FACEBOOK;
        break;
      default:
        authMethod = AuthMethod.EMAIL;
    }
    
    return User(
      id: userData.id,
      name: userData.name,
      email: userData.email,
      primaryAuthMethod: authMethod,
      linkedAuthMethods: [authMethod],
    );
  }
}

/// Data class for user information with source tracking
class UserData {
  final String id;
  final String name;
  final String email;
  final String authProvider;
  final UserDataSource source;

  const UserData({
    required this.id,
    required this.name,
    required this.email,
    required this.authProvider,
    required this.source,
  });

  @override
  String toString() {
    return 'UserData(id: $id, name: $name, email: $email, authProvider: $authProvider, source: $source)';
  }
}

/// Enum to track where user data was sourced from
enum UserDataSource {
  dynamodb,
  cognito,
}
