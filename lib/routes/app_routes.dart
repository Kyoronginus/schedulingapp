import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../splash/splash_screen.dart';

class AppRoutes {
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String splash = '/';

  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.home: (context) => const HomeScreen(),
        // AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.splash: (context) => SplashScreen(),
      };
}
