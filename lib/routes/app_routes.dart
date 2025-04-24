import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../splash/splash_screen.dart';
import '../auth/login/login_screen.dart';
import '../setting/setting_screen.dart';
import '../schedule/schedule_screen.dart';
import '../auth/register/register_screen.dart';

class AppRoutes {
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String setting = '/setting';
  static const String splash = '/';
  static const String schedule = '/schedule';

  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.setting: (context) => const SettingScreen(),
        AppRoutes.splash: (context) => SplashScreen(),
        AppRoutes.schedule: (context) => const ScheduleScreen(),
      };
}
