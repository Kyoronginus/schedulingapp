import 'package:flutter/material.dart';
import '../services/navigation_service.dart';
import '../routes/app_routes.dart';

/// A smart back button that uses navigation memory to determine where to go back
class SmartBackButton extends StatelessWidget {
  final Color? color;
  final double? size;
  final VoidCallback? onPressed;
  final bool showOnMainScreens;

  const SmartBackButton({
    super.key,
    this.color,
    this.size,
    this.onPressed,
    this.showOnMainScreens = true,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    
    // Don't show back button on schedule screen (home screen)
    if (currentRoute == AppRoutes.schedule && !showOnMainScreens) {
      return const SizedBox.shrink();
    }

    return IconButton(
      onPressed: onPressed ?? () => _handleBackPress(context),
      icon: Icon(
        Icons.arrow_back,
        color: color ?? Colors.white,
        size: size ?? 24,
      ),
    );
  }

  void _handleBackPress(BuildContext context) {
    final navigationService = NavigationService();
    final currentRoute = ModalRoute.of(context)?.settings.name;
    
    // For main app screens, use navigation memory
    if (currentRoute != null && {
      AppRoutes.schedule,
      AppRoutes.home,
      AppRoutes.addGroup,
      AppRoutes.profile,
      AppRoutes.notification,
    }.contains(currentRoute)) {
      
      // If we can go back safely, do so
      if (navigationService.canGoBack()) {
        final backRoute = navigationService.getSafeBackRoute();
        Navigator.pushReplacementNamed(context, backRoute);
      } else {
        // Default to schedule screen
        Navigator.pushReplacementNamed(context, AppRoutes.schedule);
      }
    } else {
      // For other screens, use normal back navigation
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        // Fallback to schedule screen
        Navigator.pushReplacementNamed(context, AppRoutes.schedule);
      }
    }
  }
}

/// A wrapper widget that handles system back button presses
class NavigationMemoryWrapper extends StatelessWidget {
  final Widget child;
  final String? currentRoute;

  const NavigationMemoryWrapper({
    super.key,
    required this.child,
    this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleSystemBackButton(context);
        }
      },
      child: child,
    );
  }

  void _handleSystemBackButton(BuildContext context) {
    final navigationService = NavigationService();
    
    // Let the navigation service handle the back button
    final handled = navigationService.handleBackButton(context);
    
    // If not handled by navigation service, use default behavior
    if (!handled) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      // If can't pop and not handled, the app will exit naturally
    }
  }
}

/// Mixin to add navigation memory tracking to screens
mixin NavigationMemoryMixin<T extends StatefulWidget> on State<T> {
  final NavigationService _navigationService = NavigationService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Track the current route
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute != null) {
      _navigationService.pushRoute(currentRoute);
      
      // Reset navigation memory if we reach the schedule screen
      if (currentRoute == AppRoutes.schedule) {
        _navigationService.resetToScheduleRoot();
      }
    }
  }

  /// Navigate using the navigation service
  void navigateWithMemory(String routeName, {Object? arguments}) {
    _navigationService.navigateWithHistory(context, routeName, arguments: arguments);
  }

  /// Replace current route using the navigation service
  void replaceWithMemory(String routeName, {Object? arguments}) {
    _navigationService.replaceWithHistory(context, routeName, arguments: arguments);
  }

  /// Navigate and clear all history
  void navigateAndClearMemory(String routeName, {Object? arguments}) {
    _navigationService.navigateAndClearHistory(context, routeName, arguments: arguments);
  }

  /// Get the safe back route
  String getSafeBackRoute() {
    return _navigationService.getSafeBackRoute();
  }

  /// Check if we can go back safely
  bool canGoBackSafely() {
    return _navigationService.canGoBack();
  }
}
