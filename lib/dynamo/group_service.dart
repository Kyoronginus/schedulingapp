import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../amplifyconfiguration.dart';
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import 'dart:convert';
import '../models/User.dart';
import '../models/Group.dart';

class GroupService {
  static Future<Group?> getSelectedGroup() async {
    final groups = await getUserGroups();
    return groups.isNotEmpty ? groups.first : null;
  }

  static Future<List<Group>> getUserGroups() async {
    final userId = (await Amplify.Auth.getCurrentUser()).userId;
    final request = GraphQLRequest<String>(
      document: '''
        query GetUserGroups(\$userId: ID!) {
          listGroupUsers(filter: {userId: {eq: \$userId}}) {
            items {
              group {
                id
                name
              }
            }
          }
        }
      ''',
      variables: {'userId': userId},
    );
    final response = await Amplify.API.query(request: request).response;
    final items = jsonDecode(response.data!)['listGroupUsers']['items'];
    return items.map<Group>((item) => Group.fromJson(item['group'])).toList();
  }

  static Future<void> createGroup({
    required String name,
    String? description,
  }) async {
    try {
      final userId = (await Amplify.Auth.getCurrentUser()).userId;

      // Step 1: Create the group
      final groupRequest = GraphQLRequest<String>(
        document: '''
        mutation CreateGroup(\$input: CreateGroupInput!) {
          createGroup(input: \$input) {
            id
            name
            description
            ownerId
          }
        }
      ''',
        variables: {
          'input': {
            'name': name,
            'description': description,
            'ownerId': userId,
          }
        },
      );

      final groupResponse =
          await Amplify.API.mutate(request: groupRequest).response;
      final groupData = jsonDecode(groupResponse.data!)['createGroup'];
      final groupId = groupData['id'];

      print('✅ Group created with ID: $groupId');

      // Step 2: Add creator as a GroupUser (member)
      final memberRequest = GraphQLRequest<String>(
        document: '''
        mutation CreateGroupUser(\$input: CreateGroupUserInput!) {
          createGroupUser(input: \$input) {
            id
            userId
            groupId
            isAdmin
          }
        }
      ''',
        variables: {
          'input': {
            'userId': userId,
            'groupId': groupId,
            'isAdmin': true,
          }
        },
      );

      final memberResponse =
          await Amplify.API.mutate(request: memberRequest).response;
      print('✅ GroupUser created: ${memberResponse.data}');
    } catch (e) {
      print('❌ Failed to create group or member: $e');
      rethrow;
    }
  }

  static Future<List<User>> getGroupMembers(String groupId) async {
    try {
      final request = GraphQLRequest<String>(
        document: '''
        query GetGroupMembers(\$groupId: ID!) {
          listGroupUsers(filter: {groupId: {eq: \$groupId}}) {
            items {
              user {
                id
                name
                email
                isAdmin
              }
            }
          }
        }
      ''',
        variables: {'groupId': groupId},
      );

      final response = await Amplify.API.query(request: request).response;
      final rawData = response.data;

      if (rawData == null) {
        throw Exception('API response data is null');
      }

      final decoded = jsonDecode(rawData);
      final items = decoded['listGroupUsers']?['items'];

      if (items == null) {
        throw Exception('listGroupUsers.items is null');
      }

      return items
          .where((item) => item['user'] != null)
          .map<User>((item) => User.fromJson(item['user']))
          .toList();
    } catch (e) {
      print('❌ Failed to fetch group members: $e');
      rethrow;
    }
  }
}
