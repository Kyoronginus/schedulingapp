//Color definitions for the app

import 'package:flutter/material.dart';

// Original color
Color panaceaTeal20 = const Color.fromARGB(255, 158, 239, 240);

// Primary color for the app based on design
Color primaryColor = const Color(0xFF4A80F0); // Blue color from design

MaterialColor createMaterialColor(String hexColor) {
  // Add alpha value if not provided
  if (hexColor.length == 6) {
    hexColor = 'FF$hexColor';
  }

  // Convert the hex color to an integer
  final int colorInt = int.parse(hexColor, radix: 16);
  final Color color = Color(colorInt);

  List strengths = <double>[.05];
  final swatch = <int, Color>{};
  final int r = color.r.toInt(), g = color.g.toInt(), b = color.b.toInt();

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.toARGB32(), swatch);
}
