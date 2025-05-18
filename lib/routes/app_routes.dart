import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../splash/splash_screen.dart';
import '../auth/login/login_screen.dart';
import '../auth/login/initial_login_screen.dart';
import '../auth/password/forgot_password_screen.dart';
import '../auth/password/reset_password_screen.dart';
import '../schedule/schedule_screen.dart';
import '../auth/register/register_screen.dart';
import '../dynamo/set_user_name_screen.dart';
import '../schedule/create_schedule/schedule_form_screen.dart';
import '../schedule/group/add_group_screen.dart';
import '../schedule/invite/invite_member_screen.dart';
import '../home/Profile/profile_screen.dart';

class AppRoutes {
  static const String home = '/home';
  static const String login = '/login';
  static const String emailLogin = '/emailLogin';
  static const String register = '/register';
  static const String forgotPassword = '/forgotPassword';
  static const String resetPassword = '/resetPassword';
  static const String splash = '/';
  static const String schedule = '/schedule';
  static const String inviteMember = '/inviteMember';
  static const String setUserName = '/setUserName';
  static const String scheduleForm = '/scheduleForm';
  static const String addGroup = '/addGroup';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.emailLogin: (context) => const EmailLoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
        AppRoutes.resetPassword: (context) => ResetPasswordScreen(email: ''),
        AppRoutes.splash: (context) => SplashScreen(),
        AppRoutes.schedule: (context) => const ScheduleScreen(),
        AppRoutes.scheduleForm: (context) => const ScheduleFormScreen(),
        AppRoutes.setUserName: (context) => const SetUserNameScreen(),
        AppRoutes.addGroup: (context) => const AddGroupScreen(),
        AppRoutes.inviteMember: (context) =>
            InviteMemberScreen(groupId: 'exampleGroupId'),
        AppRoutes.profile: (context) => ProfileScreen(email: ''),
      };
}
