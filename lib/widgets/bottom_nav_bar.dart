import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../routes/app_routes.dart';
import '../utils/utils_functions.dart';
import '../theme/theme_provider.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onItemTapped(BuildContext context, int index) {
    String route;
    switch (index) {
      case 0:
        route = AppRoutes.schedule;
        break;
      case 1:
        route = AppRoutes.addGroup; // This now points to GroupScreen
        break;
      case 2:
        route = AppRoutes.profile;
        break;
      default:
        route = AppRoutes.schedule;
    }
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);

    final activeColor = isDarkMode ? const Color(0xFF4CAF50) : primaryColor;
    final inactiveColor = isDarkMode ? Colors.grey.shade600 : Colors.grey;
    final backgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return BottomNavigationBar(
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(
            Icons.calendar_today,
            color: currentIndex == 0 ? activeColor : inactiveColor,
          ),
          label: 'Schedule',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.group,
            color: currentIndex == 1 ? activeColor : inactiveColor,
          ),
          label: 'Group',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.person,
            color: currentIndex == 2 ? activeColor : inactiveColor,
          ),
          label: 'Profile',
        ),
      ],
      currentIndex: currentIndex,
      selectedItemColor: activeColor,
      unselectedItemColor: inactiveColor,
      backgroundColor: backgroundColor,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      onTap: (index) => _onItemTapped(context, index),
    );
  }
}
