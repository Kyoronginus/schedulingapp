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
      print(
          'Creating group with userId: $userId , name: $name , description: $description');
      final request = GraphQLRequest<String>(
        document: '''
        mutation CreateGroup(\$input: CreateGroupInput!) {
          createGroup(input: \$input) {
            id
            name
            description
            ownerId
            members {
              items {
                id
                userId
                isAdmin
              }
            }
          }
        }
      ''',
        variables: {
          'input': {
            'name': name,
            'description': description,
            'ownerId': userId,
            'members': {
              'items': [
                {
                  'userId': userId,
                  'isAdmin': true // Automatically make creator an admin
                }
              ]
            }
          },
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      print('✅ Group created: ${response.data}');
    } catch (e) {
      print('❌ Failed to create group: $e');
      rethrow;
    }
  }
}
