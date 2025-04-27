import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../amplifyconfiguration.dart';
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import 'dart:convert';
import '../models/User.dart'; // Import User class
import '../models/Group.dart'; // Import Group class

class SetUserNameScreen extends StatefulWidget {
  const SetUserNameScreen({super.key});

  @override
  State<SetUserNameScreen> createState() => _SetUserNameScreenState();
}

class _SetUserNameScreenState extends State<SetUserNameScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final user = await Amplify.Auth.getCurrentUser();
      final userId = user.userId;

      // Query to check if the user exists
      final getUserQuery = GraphQLRequest<String>(
        document: '''
          query GetUser(\$id: ID!) {
            getUser(id: \$id) {
              id
            }
          }
        ''',
        variables: {'id': userId},
      );

      final getUserResponse =
          await Amplify.API.query(request: getUserQuery).response;

      if (getUserResponse.hasErrors) {
        print("❌ Query error: ${getUserResponse.errors}");
        throw Exception("Error fetching user.");
      }
      final dataJson = jsonDecode(getUserResponse.data!);
      final userData = dataJson['getUser'];
      if (userData == null) {
        // Create user if not exists
        final createUserMutation = GraphQLRequest<String>(
          document: '''
            mutation CreateUser(\$input: CreateUserInput!) {
              createUser(input: \$input) {
                id
                name
                email
              }
            }
          ''',
          variables: {
            'input': {
              'id': userId,
              'name': name,
              'email': user.username, // Assuming Cognito provides the email
            }
          },
        );

        final createResponse =
            await Amplify.API.mutate(request: createUserMutation).response;

        if (createResponse.hasErrors) {
          print("❌ Create error: ${createResponse.errors}");
          throw Exception("Failed to create user");
        }

        print("✅ Created user: ${createResponse.data}");
      } else {
        // Update user if exists
        final updateMutation = GraphQLRequest<String>(
          document: '''
            mutation UpdateUser(\$input: UpdateUserInput!) {
              updateUser(input: \$input) {
                id
                name
              }
            }
          ''',
          variables: {
            'input': {
              'id': userId,
              'name': name,
            }
          },
        );

        final updateResponse =
            await Amplify.API.mutate(request: updateMutation).response;

        if (updateResponse.hasErrors) {
          print("❌ Update error: ${updateResponse.errors}");
          throw Exception("Failed to update user");
        }

        print("✅ Updated user: ${updateResponse.data}");
      }

      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      print("❌ Error saving name: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save name: ${e.toString()}")),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Set Your Name")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Please enter your name:"),
            TextField(controller: _nameController),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveName,
              child: _isSaving ? CircularProgressIndicator() : Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
