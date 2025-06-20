import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/utils_functions.dart';
import '../theme/theme_provider.dart';
import 'smart_back_button.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final bool showBackButton;
  final VoidCallback? onProfileIconPressed;
  final List<Widget>? actions;
  final Color? statusBarColor;
  final Color? backgroundColor;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.onProfileIconPressed,
    this.actions,
    this.statusBarColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final appBarColor =
        backgroundColor ??
        (isDarkMode ? const Color(0xFF1E1E1E) : primaryColor);
    final statusBarColorValue = statusBarColor ?? appBarColor;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColorValue,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );

    final iconColor = isDarkMode ? const Color(0xFF4CAF50) : Colors.white;
    final titleColor = isDarkMode ? const Color(0xFF4CAF50) : Colors.white;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: appBarColor,
      elevation: 0,
      title: DefaultTextStyle(
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: titleColor,
          fontSize: 20,
        ),
        child: title,
      ),
      centerTitle: true,
      leading:
          showBackButton
              ? SmartBackButton(
                  color: iconColor,
                  size: 20,
                )
              : null,
      actions:
          actions ??
          [
            if (onProfileIconPressed != null)
              IconButton(
                icon: CircleAvatar(
                  backgroundColor:
                      isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                  child: Icon(
                    Icons.person,
                    color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                  ),
                ),
                onPressed: onProfileIconPressed,
              ),
          ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
