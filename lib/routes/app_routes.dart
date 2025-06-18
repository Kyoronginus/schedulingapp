import 'package:flutter/material.dart';
import '../auth/login/login_screen.dart';
import '../auth/password/forgot_password_screen.dart';
import '../schedule/schedule_screen.dart';
import '../auth/register/register_screen.dart';
import '../dynamo/set_user_name_screen.dart';
import '../group/group_screen.dart';
import '../schedule/invite/invite_member_screen.dart';
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
        AppRoutes.inviteMember: (context) =>
            const InviteMemberScreen(groupId: 'exampleGroupId'),
        AppRoutes.profile: (context) => const ProfileScreen(email: ''),
        AppRoutes.notification: (context) => const NotificationScreen(),
      };
}
