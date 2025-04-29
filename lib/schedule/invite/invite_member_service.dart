import '../../models/User.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';

class InviteMemberService {
  Future<User?> findUserByEmail(String email) async {
    try {
      final request = GraphQLRequest<String>(
        document: '''
        query FindUserByEmail(\$email: String!) {
          userByEmail(email: \$email) {
            items {
              id
              email
              name
            }
          }
        }
      ''',
        variables: {
          'email': email,
        },
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.data == null) {
        throw Exception('ユーザーが見つかりませんでした');
      }

      final Map<String, dynamic> data = jsonDecode(response.data!);
      final items = data['userByEmail']['items'] as List<dynamic>;

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

  Future<void> createGroupUser({
    required String userId,
    required String groupId,
    required bool isAdmin,
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
            'isAdmin': isAdmin, // スキーマにisAdminを追加するならここ！
          }
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.data == null) {
        throw Exception('GroupUser作成に失敗しました');
      }

      print('GroupUser作成成功！');
    } catch (e) {
      print('Error creating GroupUser: $e');
      rethrow;
    }
  }
}
