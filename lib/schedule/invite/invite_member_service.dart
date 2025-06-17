import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:schedulingapp/models/AuthMethod.dart';
import '../../models/User.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class InviteMemberService {
  Future<User?> findUserByEmail(String email) async {
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
        variables: {
          'email': email.trim().toLowerCase(),
        },
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.data == null || response.hasErrors) {
        debugPrint('🔴 Error finding user by email: ${response.errors}');
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.data!);
      final items = data['listUsersByEmail']['items'] as List<dynamic>;

      if (items.isEmpty) {
        // User with this email was not found
        return null;
      }

      final userData = items.first as Map<String, dynamic>;

      // --- Data Parsing Logic ---

      // Helper function to robustly convert a String to an AuthMethod enum
      AuthMethod? _parseAuthMethod(String? methodName) {
        if (methodName == null) return null;
        try {
          // Find the enum value whose name matches the string (case-insensitive)
          return AuthMethod.values.firstWhere(
            (e) => e.name.toUpperCase() == methodName.toUpperCase()
          );
        } catch (e) {
          // This catches errors if the string from the DB is not a valid enum member
          debugPrint('⚠️ Warning: Unknown AuthMethod string received: "$methodName"');
          return null;
        }
      }

      final primaryMethod = _parseAuthMethod(userData['primaryAuthMethod']);
      if (primaryMethod == null) {
        throw Exception('Failed to parse a required primaryAuthMethod from string: "${userData['primaryAuthMethod']}"');
      }

      final linkedMethodsData = userData['linkedAuthMethods'] as List<dynamic>? ?? [];
      final List<AuthMethod> linkedMethods = linkedMethodsData
          .map((method) => _parseAuthMethod(method as String?))
          .whereType<AuthMethod>() // Filters out any nulls that failed to parse
          .toList();

      return User(
        id: userData['id'],
        email: userData['email'],
        name: userData['name'],
        primaryAuthMethod: primaryMethod,
        linkedAuthMethods: linkedMethods,
      );

    } catch (e) {
      debugPrint('🔴 An exception occurred in findUserByEmail: $e');
      rethrow; // Rethrow to allow the UI layer to handle the error
    }
  }

  /// Creates a GroupUser relationship to add a user to a group.
  Future<void> createGroupUser({
    required String userId,
    required String groupId,
    bool isAdmin = false,
  }) async {
    try {
      final request = GraphQLRequest<String>(
        document: '''
        mutation CreateGroupUser(\$input: CreateGroupUserInput!) {
          createGroupUser(input: \$input) {
            id
          }
        }
        ''',
        variables: {
          'input': {
            'userId': userId,
            'groupId': groupId,
            'isAdmin': isAdmin,
          },
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.data == null || response.errors.isNotEmpty) {
        throw Exception('Failed to create GroupUser: ${response.errors}');
      }

      debugPrint('✅ Successfully created GroupUser: ${response.data}');
    } catch (e) {
      debugPrint('🔴 Error creating GroupUser: $e');
      rethrow;
    }
  }
}