import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

/// Service to manage navigation history and prevent going back to auth screens
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // Stack to keep track of navigation history
  final List<String> _navigationHistory = [];
  
  // Auth routes that should not be accessible after login
  static const Set<String> _authRoutes = {
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
  };

  // Main app routes that should be accessible
  static const Set<String> _mainAppRoutes = {
    AppRoutes.schedule,
    AppRoutes.addGroup,
    AppRoutes.profile,
    AppRoutes.notification,
  };

  /// Add a route to navigation history
  void pushRoute(String routeName) {
    // Don't add auth routes to history if user is already logged in
    if (_authRoutes.contains(routeName) && _navigationHistory.isNotEmpty) {
      return;
    }
    
    // Remove the route if it already exists to avoid duplicates
    _navigationHistory.remove(routeName);
    
    // Add to the end of the history
    _navigationHistory.add(routeName);
    
    // Limit history size to prevent memory issues
    if (_navigationHistory.length > 10) {
      _navigationHistory.removeAt(0);
    }
    
    debugPrint('📍 Navigation: Added $routeName to history. Current: $_navigationHistory');
  }

  /// Remove a route from navigation history
  void removeRoute(String routeName) {
    _navigationHistory.remove(routeName);
    debugPrint('📍 Navigation: Removed $routeName from history. Current: $_navigationHistory');
  }

  /// Get the previous route in history
  String? getPreviousRoute() {
    if (_navigationHistory.length < 2) {
      return null;
    }
    
    // Return the second-to-last route (the one before current)
    return _navigationHistory[_navigationHistory.length - 2];
  }

  /// Get the current route
  String? getCurrentRoute() {
    if (_navigationHistory.isEmpty) {
      return null;
    }
    return _navigationHistory.last;
  }

  /// Check if we can go back (not to auth screens)
  bool canGoBack() {
    final previousRoute = getPreviousRoute();
    if (previousRoute == null) {
      return false;
    }
    
    // Don't allow going back to auth routes
    return !_authRoutes.contains(previousRoute);
  }

  /// Get the safe back route (defaults to schedule if can't go back safely)
  String getSafeBackRoute() {
    if (canGoBack()) {
      return getPreviousRoute()!;
    }
    
    // Default to schedule screen as the safe fallback
    return AppRoutes.schedule;
  }

  /// Reset navigation history when reaching schedule screen (new root)
  void resetToScheduleRoot() {
    _navigationHistory.clear();
    _navigationHistory.add(AppRoutes.schedule);
    debugPrint('📍 Navigation: Reset to schedule root');
  }

  /// Clear all navigation history (used on logout)
  void clearHistory() {
    _navigationHistory.clear();
    debugPrint('📍 Navigation: Cleared all history');
  }

  /// Handle back button press with navigation memory
  bool handleBackButton(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    
    // If we're on a main app screen, use our navigation memory
    if (currentRoute != null && _mainAppRoutes.contains(currentRoute)) {
      final backRoute = getSafeBackRoute();
      
      // If back route is the same as current, go to schedule
      if (backRoute == currentRoute) {
        if (currentRoute != AppRoutes.schedule) {
          Navigator.pushReplacementNamed(context, AppRoutes.schedule);
          return true;
        }
        // If already on schedule, let system handle (exit app)
        return false;
      }
      
      // Navigate to the safe back route
      Navigator.pushReplacementNamed(context, backRoute);
      return true;
    }
    
    // For other screens, use default behavior
    return false;
  }

  /// Navigate with history tracking
  void navigateWithHistory(BuildContext context, String routeName, {Object? arguments}) {
    pushRoute(routeName);
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  /// Replace current route with history tracking
  void replaceWithHistory(BuildContext context, String routeName, {Object? arguments}) {
    // Remove current route from history if it exists
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute != null) {
      removeRoute(currentRoute);
    }
    
    pushRoute(routeName);
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  /// Navigate and clear history (used for major navigation changes)
  void navigateAndClearHistory(BuildContext context, String routeName, {Object? arguments}) {
    clearHistory();
    pushRoute(routeName);
    Navigator.pushNamedAndRemoveUntil(
      context, 
      routeName, 
      (route) => false,
      arguments: arguments,
    );
  }

  /// Get navigation history for debugging
  List<String> getHistory() => List.unmodifiable(_navigationHistory);
}
