import '../../models/User.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';

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
        }
      }
    }
  ''',
        variables: {
          'email': email.trim().toLowerCase(),
        },
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.data == null) {
        throw Exception('user is not found');
      }

      final Map<String, dynamic> data = jsonDecode(response.data!);
      final items = data['listUsersByEmail']['items'] as List<dynamic>;

      if (items.isEmpty) {
        return null;
      }

      final userData = items.first;
      return User(
        id: userData['id'],
        email: userData['email'],
        name: userData['name'],
      );
    } catch (e) {
      print('Error finding user by email: $e');
      rethrow;
    }
  }

  /// GroupUser
  Future<void> createGroupUser({
    required String userId,
    required String groupId,
    bool isAdmin = false, // defaultでfalseに
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
        throw Exception('failed to create GroupUser');
      }

      print('✅ successfully created GroupUser: ${response.data}');
    } catch (e) {
      print('🔴 Error creating GroupUser: $e');
      rethrow;
    }
  }
}
