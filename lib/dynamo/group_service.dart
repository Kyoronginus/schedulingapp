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
}
