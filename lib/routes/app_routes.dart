import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../splash/splash_screen.dart';
import '../auth/login/login_screen.dart';
import '../auth/login/initial_login_screen.dart';
import '../auth/password/forgot_password_screen.dart';
import '../auth/password/reset_password_screen.dart';
import '../auth/password/change_password_screen.dart';
import '../schedule/schedule_screen.dart';
import '../auth/register/register_screen.dart';
import '../dynamo/set_user_name_screen.dart';
import '../schedule/group/group_screen.dart';
import '../schedule/invite/invite_member_screen.dart';
import '../home/profile_screen.dart';
import '../notification/notification_screen.dart';

class AppRoutes {
  static const String home = '/home';
  static const String login = '/login';
  static const String emailLogin = '/emailLogin';
  static const String register = '/register';
  static const String forgotPassword = '/forgotPassword';
  static const String resetPassword = '/resetPassword';
  static const String changePassword = '/changePassword';
  static const String splash = '/';
  static const String schedule = '/schedule';
  static const String inviteMember = '/inviteMember';
  static const String setUserName = '/setUserName';
  static const String addGroup = '/group';
  static const String profile = '/profile';
  static const String notification = '/notification';

  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.emailLogin: (context) => const EmailLoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
        AppRoutes.resetPassword: (context) => const ResetPasswordScreen(email: ''),
        AppRoutes.changePassword: (context) => const ChangePasswordScreen(),
        AppRoutes.splash: (context) => SplashScreen(),
        AppRoutes.schedule: (context) => const ScheduleScreen(),
        AppRoutes.setUserName: (context) => const SetUserNameScreen(),
        AppRoutes.addGroup: (context) => const GroupScreen(),
        AppRoutes.inviteMember: (context) =>
            const InviteMemberScreen(groupId: 'exampleGroupId'),
        AppRoutes.profile: (context) => const ProfileScreen(email: ''),
        AppRoutes.notification: (context) => const NotificationScreen(),
      };
}
