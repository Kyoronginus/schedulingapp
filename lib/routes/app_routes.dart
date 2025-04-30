import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../splash/splash_screen.dart';
import '../auth/login/login_screen.dart';
import '../setting/setting_screen.dart';
import '../schedule/schedule_screen.dart';
import '../auth/register/register_screen.dart';
import '../dynamo/set_user_name_screen.dart';
import '../schedule/schedule_form_screen.dart';
import '../schedule/group/add_group_screen.dart';
import '../../schedule/invite/invite_member_screen.dart';
import '../../home/Profile/profile_screen.dart';

class AppRoutes {
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String setting = '/setting';
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
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.setting: (context) => const SettingScreen(),
        AppRoutes.splash: (context) => SplashScreen(),
        AppRoutes.schedule: (context) => const ScheduleScreen(),
        AppRoutes.scheduleForm: (context) => const ScheduleFormScreen(),
        AppRoutes.setUserName: (context) => const SetUserNameScreen(),
        AppRoutes.addGroup: (context) => const AddGroupScreen(),
        AppRoutes.inviteMember: (context) =>
            InviteMemberScreen(groupId: 'exampleGroupId'),
        AppRoutes.profile: (context) => ProfileScreen(email: '')
      };
}
