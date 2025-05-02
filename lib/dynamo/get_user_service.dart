import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../amplifyconfiguration.dart';
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import 'dart:convert';
import '../models/User.dart';

class AuthService {
  static Future<User> getCurrentUser() async {
    try {
      final authUser = await Amplify.Auth.getCurrentUser();
      final request = GraphQLRequest<String>(
        document: '''
          query GetUser(\$id: ID!) {
            getUser(id: \$id) {
              id
              email
              name
            }
          }
        ''',
        variables: {'id': authUser.userId},
      );
      final response = await Amplify.API.query(request: request).response;
      return User.fromJson(jsonDecode(response.data!)['getUser']);
    } on AuthException catch (e) {
      throw Exception('You need to login first: ${e.message}');
    }
  }
}
