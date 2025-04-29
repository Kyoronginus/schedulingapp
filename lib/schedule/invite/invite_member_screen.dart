import 'dart:convert'; // ← 追加
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart'; // ← 追加
import '../../widgets/custom_app_bar.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../models/User.dart';
import '../../widgets/custom_app_bar.dart';

class InviteMemberScreen extends StatefulWidget {
  final String groupId;
  const InviteMemberScreen({required this.groupId, super.key});

  @override
  _InviteMemberScreenState createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final _emailController = TextEditingController();
  bool _isAdmin = false;

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
            'isAdmin': isAdmin,
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

  void _inviteMember() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メールアドレスを入力してください')),
      );
      return;
    }

    try {
      final user = await findUserByEmail(email);
      if (user == null) {
        throw Exception('ユーザーが見つかりませんでした');
      }

      await createGroupUser(
        userId: user.id,
        groupId: widget.groupId,
        isAdmin: _isAdmin,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('招待しました！')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('招待に失敗しました: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('Invite Member'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: '招待する人のEmail'),
            ),
            Row(
              children: [
                Checkbox(
                  value: _isAdmin,
                  onChanged: (value) {
                    setState(() {
                      _isAdmin = value ?? false;
                    });
                  },
                ),
                Text('スケジュール作成権限を与える')
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _inviteMember,
              child: Text('招待する'),
            ),
          ],
        ),
      ),
    );
  }
}
