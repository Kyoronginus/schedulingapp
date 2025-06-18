import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
        route = AppRoutes.addGroup; // This points to GroupScreen
        break;
      case 2:
        route = AppRoutes.notification; // This points to NotificationScreen
        break;
      case 3:
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

    final activeColor = isDarkMode ? const Color(0xFF4CAF50) : primaryColor;
    final inactiveColor = isDarkMode ? Colors.grey.shade600 : const Color(0xFF8F9BB3);
    final backgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    

    return Container(
      height: 115.0,
      decoration: BoxDecoration(
       color: backgroundColor, // Properti color dipindahkan ke dalam decoration
       borderRadius: const BorderRadius.only(
         topLeft: Radius.circular(24.0),   // Sudut kiri atas melengkung
         topRight: Radius.circular(24.0),  // Sudut kanan atas melengkung
       ),
       boxShadow: [ // Anda bisa menambahkan bayangan di sini jika mau
         BoxShadow(
           color: Colors.black.withValues(alpha:0.1),
           blurRadius: 10,
         ),
       ],
     ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
         topLeft: Radius.circular(24.0),
         topRight: Radius.circular(24.0),
        ),
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              label: 'Schedule',
              icon: SvgPicture.asset(
                 'assets/icons/calendar_navbar-icon.svg',
                 width: 34,
                 height: 34,
                 colorFilter: ColorFilter.mode(
                   // Logika ternary langsung di sini
                   currentIndex == 0 ? activeColor : inactiveColor,
                   BlendMode.srcIn,
                 ),
              )
            ),
            BottomNavigationBarItem(
              label: 'Group',
              icon: SvgPicture.asset(
                 'assets/icons/group-icon.svg',
                 width: 34,
                 height: 34,
                 colorFilter: ColorFilter.mode(
                   // Logika ternary langsung di sini
                   currentIndex == 1 ? activeColor : inactiveColor,
                   BlendMode.srcIn,
                 ),
              )
            ),
            BottomNavigationBarItem(
              label: 'Notification',
              icon: SvgPicture.asset(
                 'assets/icons/notification-icon.svg',
                 width: 34,
                 height: 34,
                 colorFilter: ColorFilter.mode(
                   // Logika ternary langsung di sini
                   currentIndex == 2 ? activeColor : inactiveColor,
                   BlendMode.srcIn,
                 ),
              )
            ),
            BottomNavigationBarItem(
              label: 'Profile',
              icon: SvgPicture.asset(
                 'assets/icons/profile-icon.svg',
                 width: 34,
                 height: 34,
                 colorFilter: ColorFilter.mode(
                   // Logika ternary langsung di sini
                   currentIndex == 3 ? activeColor : inactiveColor,
                   BlendMode.srcIn,
                 ),
              )
            ),
          ],
          currentIndex: currentIndex,
          backgroundColor: backgroundColor, 
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: activeColor),
          unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: inactiveColor),
          onTap: (index) => _onItemTapped(context, index),
        ),
      ),
    );
  }
}
