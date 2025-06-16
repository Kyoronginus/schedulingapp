import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter/material.dart';
import '../models/AuthMethod.dart';

/// Service for detecting and managing authentication methods
class AuthMethodService {
  
  /// Detect the current authentication method based on Cognito session data
  static Future<AuthMethod> detectCurrentAuthMethod() async {
    try {
      // Get the current auth session
      final session = await Amplify.Auth.fetchAuthSession(
        options: const FetchAuthSessionOptions(),
      ) as CognitoAuthSession;

      // Get user attributes to check for identity providers
      final attributes = await Amplify.Auth.fetchUserAttributes();
      
      // Check for identity provider in user attributes
      final identityProviderAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey.key == 'identities',
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.custom('identities'),
          value: '',
        ),
      );

      debugPrint('🔍 AuthMethodService: Identity provider attribute: ${identityProviderAttr.value}');

      // Parse identity provider information
      if (identityProviderAttr.value.isNotEmpty) {
        final identityValue = identityProviderAttr.value.toLowerCase();
        if (identityValue.contains('google')) {
          debugPrint('✅ AuthMethodService: Detected Google authentication');
          return AuthMethod.GOOGLE;
        } else if (identityValue.contains('facebook')) {
          debugPrint('✅ AuthMethodService: Detected Facebook authentication');
          return AuthMethod.FACEBOOK;
        }
      }

      // Alternative method: Check identity ID for provider information
      final identityIdResult = session.identityIdResult;
      if (identityIdResult.value.isNotEmpty) {
        final identityId = identityIdResult.value.toLowerCase();
        debugPrint('🔍 AuthMethodService: Identity ID: $identityId');
        
        if (identityId.contains('google')) {
          debugPrint('✅ AuthMethodService: Detected Google authentication via identity ID');
          return AuthMethod.GOOGLE;
        } else if (identityId.contains('facebook')) {
          debugPrint('✅ AuthMethodService: Detected Facebook authentication via identity ID');
          return AuthMethod.FACEBOOK;
        }
      }

      // Alternative method: Check user attributes for provider information
      debugPrint('🔍 AuthMethodService: Checking user attributes for provider info');

      // Check for custom attributes that might indicate OAuth provider
      final customAttrs = attributes.where(
        (attr) => attr.userAttributeKey.key.startsWith('custom:') ||
                 attr.userAttributeKey.key.contains('provider') ||
                 attr.userAttributeKey.key.contains('identity')
      ).toList();

      for (final attr in customAttrs) {
        debugPrint('🔍 AuthMethodService: Custom attribute: ${attr.userAttributeKey.key} = ${attr.value}');
        final value = attr.value.toLowerCase();
        if (value.contains('google')) {
          debugPrint('✅ AuthMethodService: Detected Google via custom attribute');
          return AuthMethod.GOOGLE;
        } else if (value.contains('facebook')) {
          debugPrint('✅ AuthMethodService: Detected Facebook via custom attribute');
          return AuthMethod.FACEBOOK;
        }
      }

      // Check if user has a password (email/password users typically have passwords)
      // This is a fallback method - if no OAuth provider is detected, assume email
      debugPrint('✅ AuthMethodService: No OAuth provider detected, defaulting to Email authentication');
      return AuthMethod.EMAIL;

    } catch (e) {
      debugPrint('❌ AuthMethodService: Error detecting auth method: $e');
      // Default to email if detection fails
      return AuthMethod.EMAIL;
    }
  }

  /// Detect all linked authentication methods for the current user
  static Future<List<AuthMethod>> detectLinkedAuthMethods() async {
    try {
      final currentMethod = await detectCurrentAuthMethod();
      final linkedMethods = <AuthMethod>[currentMethod];

      // Get user attributes to check for linked providers
      final attributes = await Amplify.Auth.fetchUserAttributes();
      
      // Check for multiple identity providers
      final identityProviderAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey.key == 'identities',
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.custom('identities'),
          value: '',
        ),
      );

      if (identityProviderAttr.value.isNotEmpty) {
        final identityValue = identityProviderAttr.value.toLowerCase();
        
        // Check for Google
        if (identityValue.contains('google') && !linkedMethods.contains(AuthMethod.GOOGLE)) {
          linkedMethods.add(AuthMethod.GOOGLE);
        }
        
        // Check for Facebook
        if (identityValue.contains('facebook') && !linkedMethods.contains(AuthMethod.FACEBOOK)) {
          linkedMethods.add(AuthMethod.FACEBOOK);
        }
      }

      // If user has email verification, they likely have email/password capability
      final emailVerifiedAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey == CognitoUserAttributeKey.emailVerified,
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.emailVerified,
          value: 'false',
        ),
      );

      if (emailVerifiedAttr.value == 'true' && !linkedMethods.contains(AuthMethod.EMAIL)) {
        // Only add email if it's not an OAuth-only account
        // We'll determine this based on whether a password was set
        linkedMethods.add(AuthMethod.EMAIL);
      }

      debugPrint('✅ AuthMethodService: Detected linked methods: $linkedMethods');
      return linkedMethods;

    } catch (e) {
      debugPrint('❌ AuthMethodService: Error detecting linked methods: $e');
      // Return current method as fallback
      final currentMethod = await detectCurrentAuthMethod();
      return [currentMethod];
    }
  }

  /// Check if the current user is an OAuth-only user (no email/password)
  static Future<bool> isOAuthOnlyUser() async {
    try {
      final currentMethod = await detectCurrentAuthMethod();
      return currentMethod == AuthMethod.GOOGLE || currentMethod == AuthMethod.FACEBOOK;
    } catch (e) {
      debugPrint('❌ AuthMethodService: Error checking OAuth-only status: $e');
      return false;
    }
  }

  /// Get a user-friendly string representation of the auth method
  static String getAuthMethodDisplayName(AuthMethod method) {
    switch (method) {
      case AuthMethod.EMAIL:
        return 'Email';
      case AuthMethod.GOOGLE:
        return 'Google';
      case AuthMethod.FACEBOOK:
        return 'Facebook';
    }
  }

  /// Get the primary authentication method (the one used for initial registration)
  static Future<AuthMethod> getPrimaryAuthMethod() async {
    // For now, this is the same as current auth method
    // In the future, this could be stored in user preferences or database
    return await detectCurrentAuthMethod();
  }
}
