import 'package:flutter/material.dart';
import '../auth/login/login_screen.dart';
import '../auth/password/forgot_password_screen.dart';
import '../schedule/schedule_screen.dart';
import '../auth/register/register_screen.dart';
import '../dynamo/set_user_name_screen.dart';
import '../group/group_screen.dart';
import '../profile/profile_screen.dart';
import '../notification/notification_screen.dart';

class AppRoutes {
  static const String schedule = '/schedule';
  static const String login = '/login';
  static const String emailLogin = '/emailLogin';
  static const String register = '/register';
  static const String forgotPassword = '/forgotPassword';
  // static const String changePassword = '/changePassword';
  static const String inviteMember = '/inviteMember';
  static const String setUserName = '/setUserName';
  static const String addGroup = '/group';
  static const String profile = '/profile';
  static const String notification = '/notification';

  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.schedule: (context) => const ScheduleScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
        // AppRoutes.changePassword: (context) => const ChangePasswordScreen(),
        AppRoutes.setUserName: (context) => const SetUserNameScreen(),
        AppRoutes.addGroup: (context) => const GroupScreen(),
        // Note: InviteMemberScreen is navigated to via MaterialPageRoute with proper groupId
        // so we don't include it in static routes to avoid null check errors
        AppRoutes.profile: (context) => const ProfileScreen(email: ''),
        AppRoutes.notification: (context) => const NotificationScreen(),
      };
}
