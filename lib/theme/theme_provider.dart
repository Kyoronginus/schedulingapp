import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // Colors for light theme
  static const Color _primaryColorLight = Color(0xFF4A80F0); // Blue

  // Colors for dark theme
  static const Color _primaryColorDark = Color(0xFF1E1E1E); // Black
  static const Color _accentColorDark = Color(0xFF4CAF50); // Green

  ThemeProvider() {
    // Initialize with default value
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  ThemeData getTheme() {
    return _isDarkMode ? _darkTheme : _lightTheme;
  }

  // Light theme
  ThemeData get _lightTheme => ThemeData(
        brightness: Brightness.light,
        primaryColor: _primaryColorLight,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: _primaryColorLight,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColorLight,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dividerColor: Colors.grey.shade300,
      );

  // Dark theme
  ThemeData get _darkTheme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: _primaryColorDark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: _primaryColorDark,
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: _accentColorDark),
          actionsIconTheme: IconThemeData(color: _accentColorDark),
          titleTextStyle: TextStyle(color: _accentColorDark, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColorDark,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF2A2A2A),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dividerColor: Colors.grey.shade800,
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return _accentColorDark;
            }
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return _accentColorDark.withValues(alpha:0.5);
            }
            return Colors.grey.withValues(alpha:0.5);
          }),
        ),
        iconTheme: const IconThemeData(
          color: _accentColorDark,
        ),
      );
}
