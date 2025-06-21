import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'routes/app_routes.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'amplifyconfiguration.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore/amplify_datastore.dart' show AmplifyDataStore;
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:schedulingapp/models/ModelProvider.dart';
import 'package:schedulingapp/theme/theme_provider.dart';
import 'package:schedulingapp/providers/group_selection_provider.dart';
import 'package:schedulingapp/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final authPlugin = AmplifyAuthCognito();
    await Amplify.addPlugin(authPlugin);

    // Add API plugin
    await Amplify.addPlugin(AmplifyAPI(modelProvider: ModelProvider.instance));

    // Add DataStore plugin - required for notifications and schedules
    final datastorePlugin = AmplifyDataStore(modelProvider: ModelProvider.instance);
    await Amplify.addPlugin(datastorePlugin);

    // Add Storage plugin for profile pictures
    await Amplify.addPlugin(AmplifyStorageS3());

    await Amplify.configure(amplifyconfig);

    // Initialize notification service
    await NotificationService.initialize();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => GroupSelectionProvider()),
        ],
        child: const SchedulingApp(),
      ),
    );
  } on AmplifyAlreadyConfiguredException {
    debugPrint("Amplify already configured");

    // Initialize notification service
    await NotificationService.initialize();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => GroupSelectionProvider()),
        ],
        child: const SchedulingApp(),
      ),
    );
  }
}

class SchedulingApp extends StatelessWidget {
  const SchedulingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Show loading screen until theme is initialized
        if (!themeProvider.isInitialized) {
          return MaterialApp(
            title: 'Scheduling App',
            theme: ThemeData.light(), // Default theme while loading
            home: const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            debugShowCheckedModeBanner: false,
          );
        }

        // Theme is loaded, show the actual app
        return MaterialApp(
          title: 'Scheduling App',
          theme: themeProvider.getTheme(),
          home: const AuthWrapper(),
          routes: AppRoutes.routes,
          onGenerateRoute: (settings) {
            return null;
          },
          onUnknownRoute: (settings) {
            debugPrint('⚠️ Unknown route: ${settings.name}');
            return MaterialPageRoute(
              builder: (context) => const AuthWrapper(),
            );
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 1)); // Brief loading

    try {
      // Check if user is signed in
      final result = await Amplify.Auth.fetchAuthSession();
      final isSignedIn = result.isSignedIn;

      if (mounted) {
        if (isSignedIn) {
          // User is signed in, navigate to schedule screen
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.schedule,
            (route) => false,
          );
        } else {
          // No user is signed in, navigate to register screen
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.register,
            (route) => false,
          );
        }
      }
    } catch (e) {
      // Error checking auth status, default to register screen
      debugPrint('Error checking auth status: $e');
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.register,
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
