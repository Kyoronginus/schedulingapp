import 'package:flutter/material.dart';
import 'routes/app_routes.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'amplifyconfiguration.dart';
import 'package:amplify_api/amplify_api.dart'; // Ensure this import is correct

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final authPlugin = AmplifyAuthCognito();
    await Amplify.addPlugin(authPlugin);

    final apiPlugin = AmplifyAPI();
    await Amplify.addPlugin(apiPlugin);

    await Amplify.configure(amplifyconfig);

    runApp(const SchedulingApp());
  } on AmplifyAlreadyConfiguredException {
    print("Amplify already configured");
    runApp(const SchedulingApp());
  }
}

class SchedulingApp extends StatelessWidget {
  const SchedulingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scheduling App',
      theme: ThemeData(
        primarySwatch: Colors.cyan,
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
        appBarTheme: const AppBarTheme(
          backgroundColor:
              Color.fromARGB(255, 158, 239, 240), // Example hexadecimal color
          foregroundColor: Color.fromARGB(255, 118, 176, 194),
        ),
      ),
      initialRoute: '/',
      routes: AppRoutes.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
