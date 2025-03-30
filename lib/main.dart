import 'package:flutter/material.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SchedulingApp());
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
