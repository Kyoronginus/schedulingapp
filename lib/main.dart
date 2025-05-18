import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'routes/app_routes.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'amplifyconfiguration.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:schedulingapp/models/ModelProvider.dart';
import 'package:schedulingapp/theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final authPlugin = AmplifyAuthCognito();
    await Amplify.addPlugin(authPlugin);

    await Amplify.addPlugin(AmplifyAPI(modelProvider: ModelProvider.instance));
    await Amplify.configure(amplifyconfig);

    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const SchedulingApp(),
      ),
    );
  } on AmplifyAlreadyConfiguredException {
    print("Amplify already configured");
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const SchedulingApp(),
      ),
    );
  }
}

class SchedulingApp extends StatelessWidget {
  const SchedulingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Scheduling App',
      theme: themeProvider.getTheme(),
      initialRoute: '/',
      routes: AppRoutes.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
