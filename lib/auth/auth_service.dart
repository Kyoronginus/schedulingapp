import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter/material.dart';
import '../amplifyconfiguration.dart';
import '../models/User.dart';
import '../services/secure_storage_service.dart';
import 'dart:convert';

Future<void> initAmplify() async {
  try {
    final authPlugin = AmplifyAuthCognito();
    await Amplify.addPlugin(authPlugin);
    await Amplify.configure(amplifyconfig);
    print('✅ Amplify configured');
  } catch (e) {
    print('⚠️ Amplify already configured: $e');
  }
}

Future<void> signUp(String email, String password) async {
  final userAttributes = {
    CognitoUserAttributeKey.email: email,
  };

  final result = await Amplify.Auth.signUp(
    username: email,
    password: password,
    options: CognitoSignUpOptions(userAttributes: userAttributes),
  );

  print('✅ Sign up result: ${result.isSignUpComplete}');
}

Future<void> confirmCode(String email, String code) async {
  final result = await Amplify.Auth.confirmSignUp(
    username: email,
    confirmationCode: code,
  );

  print('✅ Confirm sign up: ${result.isSignUpComplete}');
}

Future<void> login(String email, String password) async {
  try{
    final result = await Amplify.Auth.signIn(
      username: email,
      password: password,
    );

    if(!result.isSignedIn){
      final nextStep = result.nextStep.signInStep;
      if (nextStep == AuthSignInStep.confirmSignUp){
        throw Exception(
          'Your account is not confirmed. Please verify your email.',
        );
      } else {
        throw Exception(
          'Login failed. Make sure your email and password are correct.'
        );
      }
    }

    debugPrint('✅ Login success: ${result.isSignedIn}');

    // Store the password securely for display purposes
    await SecureStorageService.storePassword(password);

    // Ensure user exists in DynamoDB after successful login
    try {
      await ensureUserExists();
      debugPrint('✅ User record verified/created in database');
    } catch (e) {
      debugPrint('⚠️ Could not create user record: $e');
      // Don't throw here - user can complete profile setup later
    }

  } on AuthException catch (e) {
  throw Exception(e.message);
  }
}

/// Creates a user record in DynamoDB if it doesn't exist
Future<User> ensureUserExists() async {
  try {
    // First try to get the existing user
    return await getCurrentUser();
  } catch (e) {
    debugPrint('🔍 AuthService: User not found, creating new user record...');

    // If user doesn't exist, create it
    final authUser = await Amplify.Auth.getCurrentUser();
    final attributes = await Amplify.Auth.fetchUserAttributes();

    // Get email and name from Cognito attributes
    final emailAttr = attributes.firstWhere(
      (attr) => attr.userAttributeKey == CognitoUserAttributeKey.email,
      orElse: () => const AuthUserAttribute(
        userAttributeKey: CognitoUserAttributeKey.email,
        value: '',
      ),
    );

    final nameAttr = attributes.firstWhere(
      (attr) => attr.userAttributeKey == CognitoUserAttributeKey.name,
      orElse: () => const AuthUserAttribute(
        userAttributeKey: CognitoUserAttributeKey.name,
        value: '',
      ),
    );

    final email = emailAttr.value;
    final name = nameAttr.value;

    if (email.isEmpty) {
      throw Exception('Email is required to create user profile');
    }

    if (name.isEmpty) {
      throw Exception('Name is required to create user profile');
    }

    debugPrint('🔍 AuthService: Creating user with email: $email, name: $name');

    // Create user in DynamoDB
    final request = GraphQLRequest<String>(
      document: '''
        mutation CreateUser(\$input: CreateUserInput!) {
          createUser(input: \$input) {
            id
            email
            name
          }
        }
      ''',
      variables: {
        'input': {
          'id': authUser.userId,
          'email': email,
          'name': name,
        }
      },
    );

    final response = await Amplify.API.mutate(request: request).response;

    if (response.hasErrors) {
      debugPrint('❌ AuthService: GraphQL errors creating user: ${response.errors}');
      throw Exception('Failed to create user: ${response.errors.map((e) => e.message).join(', ')}');
    }

    if (response.data == null) {
      debugPrint('❌ AuthService: No data returned from user creation');
      throw Exception('Failed to create user: No data returned');
    }

    final responseJson = jsonDecode(response.data!);
    final userData = responseJson['createUser'];

    if (userData == null) {
      debugPrint('❌ AuthService: No createUser data in response');
      throw Exception('Failed to create user: Invalid response');
    }

    final user = User.fromJson(userData);
    debugPrint('✅ AuthService: Successfully created user: ${user.toString()}');
    return user;
  }
}

Future<User> getCurrentUser() async {
  try {
    // Get the authenticated user
    final authUser = await Amplify.Auth.getCurrentUser();
    debugPrint('🔍 AuthService: Got auth user with ID: ${authUser.userId}');

    // Query the user data from the API
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

    debugPrint('🔍 AuthService: Sending GraphQL query for user: ${authUser.userId}');
    final response = await Amplify.API.query(request: request).response;

    // Check for GraphQL errors
    if (response.hasErrors) {
      debugPrint('❌ AuthService: GraphQL errors: ${response.errors}');
      throw Exception('GraphQL errors: ${response.errors.map((e) => e.message).join(', ')}');
    }

    // Check if response data exists
    if (response.data == null) {
      debugPrint('❌ AuthService: No data returned from GraphQL query');
      throw Exception('No data returned from user query');
    }

    // Parse the JSON response
    final Map<String, dynamic> responseJson;
    try {
      responseJson = jsonDecode(response.data!);
      debugPrint('🔍 AuthService: Parsed response JSON: $responseJson');
    } catch (e) {
      debugPrint('❌ AuthService: Failed to parse JSON: $e');
      throw Exception('Failed to parse response JSON: $e');
    }

    // Check if getUser data exists
    final userData = responseJson['getUser'];
    if (userData == null) {
      debugPrint('❌ AuthService: User not found in database for ID: ${authUser.userId}');
      throw Exception('User not found in database. Please complete your profile setup.');
    }

    // Create and return User object
    final user = User.fromJson(userData);
    debugPrint('✅ AuthService: Successfully created User object: ${user.toString()}');
    return user;

  } on AuthException catch (e) {
    debugPrint('❌ AuthService: Auth exception: ${e.message}');
    throw Exception('Authentication error: ${e.message}');
  } catch (e) {
    debugPrint('❌ AuthService: Unexpected error: $e');
    rethrow;
  }
}

/// Sign in with Google using Amplify Auth
Future<bool> signInWithGoogle(BuildContext context) async {
  try {
    // Start the sign-in process
    final result = await Amplify.Auth.signInWithWebUI(
      provider: AuthProvider.google,
      options: const CognitoSignInWithWebUIOptions(
        isPreferPrivateSession: false,
      ),
    );

    if (result.isSignedIn) {
      debugPrint('✅ Google Sign In Success');

      // Ensure user exists in DynamoDB after successful Google login
      try {
        await ensureUserExists();
        debugPrint('✅ User record verified/created in database');
      } catch (e) {
        debugPrint('⚠️ Could not create user record: $e');
        // Don't throw here - user can complete profile setup later
      }

      return true;
    } else {
      debugPrint('❌ Google Sign In Failed');
      return false;
    }
  } on AmplifyException catch (e) {
    print('❌ Google Sign In Error: ${e.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Google Sign In Error: ${e.message}')),
    );
    return false;
  }
}

/// Sign in with Facebook using Amplify Auth
Future<bool> signInWithFacebook(BuildContext context) async {
  try {
    // Start the sign-in process
    final result = await Amplify.Auth.signInWithWebUI(
      provider: AuthProvider.facebook,
      options: const CognitoSignInWithWebUIOptions(
        isPreferPrivateSession: false,
      ),
    );

    if (result.isSignedIn) {
      debugPrint('✅ Facebook Sign In Success');

      // Ensure user exists in DynamoDB after successful Facebook login
      try {
        await ensureUserExists();
        debugPrint('✅ User record verified/created in database');
      } catch (e) {
        debugPrint('⚠️ Could not create user record: $e');
        // Don't throw here - user can complete profile setup later
      }

      return true;
    } else {
      debugPrint('❌ Facebook Sign In Failed');
      return false;
    }
  } on AmplifyException catch (e) {
    print('❌ Facebook Sign In Error: ${e.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Facebook Sign In Error: ${e.message}')),
    );
    return false;
  }
}
