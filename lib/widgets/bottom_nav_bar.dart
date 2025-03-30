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
        // route = AppRoutes.pesan;
        break;
      case 1:
        // route = AppRoutes.kondisi;
        break;
      case 2:
        // route = AppRoutes.home;
        break;
      case 3:
        // route = AppRoutes.riwayat;
        break;
      case 4:
        // route = AppRoutes.pengaturan;
        break;
      default:
        route = AppRoutes.home;
    }
    // Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Image.asset(
            currentIndex == 0
                ? 'assets/images/appbar_icons/pesan.png'
                : 'assets/images/appbar_icons/pesan_hitam.png',
            width: 22,
            height: 22,
          ),
          label: 'Pesan',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            currentIndex == 1
                ? 'assets/images/appbar_icons/kondisi.png'
                : 'assets/images/appbar_icons/kondisi_hitam.png',
            width: 22,
            height: 22,
          ),
          label: 'Kondisi',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            currentIndex == 2
                ? 'assets/images/appbar_icons/beranda.png'
                : 'assets/images/appbar_icons/beranda_hitam.png',
            width: 22,
            height: 22,
          ),
          label: 'Beranda',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            currentIndex == 3
                ? 'assets/images/appbar_icons/riwayat.png'
                : 'assets/images/appbar_icons/riwayat_hitam.png',
            width: 22,
            height: 22,
          ),
          label: 'Riwayat',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            currentIndex == 4
                ? 'assets/images/appbar_icons/pengaturan.png'
                : 'assets/images/appbar_icons/pengaturan_hitam.png',
            width: 22,
            height: 22,
          ),
          label: 'Pengaturan',
        ),
      ],
      currentIndex: currentIndex,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black,
      backgroundColor: panaceaTeal20,
      type: BottomNavigationBarType
          .fixed, // Ensures all labels are always visible
      selectedLabelStyle: const TextStyle(fontSize: 12), // Selected font size
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      onTap: (index) => _onItemTapped(context, index),
    );
  }
}
