import 'package:flutter/material.dart';

/// A controller that provides automatic reload functionality and pull-to-refresh
/// for navbar screens when data changes occur
class RefreshController extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final bool enablePullToRefresh;
  final bool autoRefreshOnDataChange;
  final Duration autoRefreshInterval;
  final String? refreshIndicatorText;

  const RefreshController({
    super.key,
    required this.child,
    required this.onRefresh,
    this.enablePullToRefresh = true,
    this.autoRefreshOnDataChange = true,
    this.autoRefreshInterval = const Duration(minutes: 5),
    this.refreshIndicatorText,
  });

  @override
  State<RefreshController> createState() => _RefreshControllerState();
}

class _RefreshControllerState extends State<RefreshController>
    with WidgetsBindingObserver {
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastRefreshTime = DateTime.now();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Auto-refresh when app comes back to foreground
    if (state == AppLifecycleState.resumed && widget.autoRefreshOnDataChange) {
      final now = DateTime.now();
      if (_lastRefreshTime == null || 
          now.difference(_lastRefreshTime!) > widget.autoRefreshInterval) {
        _performRefresh();
      }
    }
  }

  Future<void> _performRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await widget.onRefresh();
      _lastRefreshTime = DateTime.now();
    } catch (e) {
      debugPrint('Refresh error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enablePullToRefresh) {
      return widget.child;
    }

    return RefreshIndicator(
      onRefresh: _performRefresh,
      displacement: 40.0,
      strokeWidth: 2.0,
      color: Theme.of(context).primaryColor,
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          widget.child,
          if (_isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A mixin that provides automatic data refresh capabilities for screens
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  bool _isAutoRefreshEnabled = true;
  DateTime? _lastDataUpdate;

  /// Override this method to implement the refresh logic
  Future<void> refreshData();

  /// Call this method when data changes to trigger auto-refresh
  void notifyDataChanged() {
    _lastDataUpdate = DateTime.now();
    if (_isAutoRefreshEnabled && mounted) {
      refreshData();
    }
  }

  /// Enable or disable auto-refresh
  void setAutoRefreshEnabled(bool enabled) {
    _isAutoRefreshEnabled = enabled;
  }

  /// Check if data needs refresh based on last update time
  bool shouldRefreshData({Duration maxAge = const Duration(minutes: 5)}) {
    if (_lastDataUpdate == null) return true;
    return DateTime.now().difference(_lastDataUpdate!) > maxAge;
  }

  /// Get the last data update time
  DateTime? get lastDataUpdate => _lastDataUpdate;

  /// Check if auto-refresh is enabled
  bool get isAutoRefreshEnabled => _isAutoRefreshEnabled;
}

/// A widget that wraps content with automatic refresh capabilities
class AutoRefreshWrapper extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Duration refreshInterval;
  final bool enableAutoRefresh;

  const AutoRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshInterval = const Duration(minutes: 5),
    this.enableAutoRefresh = true,
  });

  @override
  State<AutoRefreshWrapper> createState() => _AutoRefreshWrapperState();
}

class _AutoRefreshWrapperState extends State<AutoRefreshWrapper>
    with AutoRefreshMixin {
  @override
  void initState() {
    super.initState();
    if (widget.enableAutoRefresh) {
      // Initial data load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        refreshData();
      });
    }
  }

  @override
  Future<void> refreshData() async {
    try {
      await widget.onRefresh();
      notifyDataChanged();
    } catch (e) {
      debugPrint('Auto refresh error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshController(
      onRefresh: refreshData,
      enablePullToRefresh: true,
      autoRefreshOnDataChange: widget.enableAutoRefresh,
      autoRefreshInterval: widget.refreshInterval,
      child: widget.child,
    );
  }
}

/// A utility class for managing global refresh state
class GlobalRefreshManager {
  static final GlobalRefreshManager _instance = GlobalRefreshManager._internal();
  factory GlobalRefreshManager() => _instance;
  GlobalRefreshManager._internal();

  final List<VoidCallback> _refreshCallbacks = [];

  /// Register a refresh callback
  void registerRefreshCallback(VoidCallback callback) {
    _refreshCallbacks.add(callback);
  }

  /// Unregister a refresh callback
  void unregisterRefreshCallback(VoidCallback callback) {
    _refreshCallbacks.remove(callback);
  }

  /// Trigger refresh for all registered callbacks
  void triggerGlobalRefresh() {
    for (final callback in _refreshCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Global refresh callback error: $e');
      }
    }
  }

  /// Clear all refresh callbacks
  void clearAllCallbacks() {
    _refreshCallbacks.clear();
  }
}
