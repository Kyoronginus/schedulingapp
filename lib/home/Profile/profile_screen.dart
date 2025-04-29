import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class ProfileScreen extends StatefulWidget {
  final String email;

  const ProfileScreen({Key? key, required this.email}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createUserProfile(String name) async {
    setState(() => _isLoading = true);
    try {
      final user = await Amplify.Auth.getCurrentUser();

      // Fetch email directly from Cognito
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final emailAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey == CognitoUserAttributeKey.email,
        orElse: () => AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.email,
          value: '',
        ),
      );
      final email = emailAttr?.value ?? 'no-email@example.com';

      final request = GraphQLRequest<String>(
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
          'input': {'id': user.userId, 'email': email, 'name': name}
        },
        authorizationMode: APIAuthorizationType.userPools,
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.data != null) {
        print('✅ Created User: ${response.data}');
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        print('❌ No data returned from the mutation.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create user profile.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Registered Email: ${widget.email}'),
            Text(''),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please enter your name')),
                        );
                        return;
                      }
                      _createUserProfile(name);
                    },
              child: _isLoading
                  ? CircularProgressIndicator()
                  : const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
