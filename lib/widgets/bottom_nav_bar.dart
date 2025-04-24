import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../utils/utils_functions.dart';

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
        //       // Assuming you want to navigate to the home screen for index 1 as well
        //       // You can change this to the appropriate route if needed
        route = AppRoutes.home;
        break;
      case 2:
        //       // Assuming you want to navigate to the home screen for index 2 as well
        //       // You can change this to the appropriate route if needed
        route = AppRoutes.setting;
        break;
      default:
        route = AppRoutes.home;
    }
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(
            Icons.schedule,
            color: currentIndex == 0 ? Colors.black : Colors.grey,
          ),
          label: 'Schedule',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.home,
            color: currentIndex == 1 ? Colors.black : Colors.grey,
          ),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.settings,
            color: currentIndex == 2 ? Colors.black : Colors.grey,
          ),
          label: 'Setting',
        ),
      ],
      currentIndex: currentIndex,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      backgroundColor: panaceaTeal20,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      onTap: (index) => _onItemTapped(context, index),
    );
  }
}
