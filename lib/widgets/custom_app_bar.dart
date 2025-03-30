import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/utils_functions.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final bool showBackButton;
  final VoidCallback? onProfileIconPressed;
  final List<Widget>? actions;
  final Color statusBarColor;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.onProfileIconPressed,
    this.actions,
    this.statusBarColor = Colors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: Brightness.dark,
    ));

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      title: DefaultTextStyle(
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black,
          fontSize: 24,
        ),
        child: title,
      ),
      centerTitle: true,
      leading: showBackButton
          ? IconButton(
              icon: Image.asset(
                'assets/images/Prev1.png',
                width: 24,
                height: 24,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            )
          : null,
      actions: actions ??
          [
            if (onProfileIconPressed != null)
              IconButton(
                icon: CircleAvatar(
                  backgroundColor: Colors.cyan,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                onPressed: onProfileIconPressed,
              ),
          ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
