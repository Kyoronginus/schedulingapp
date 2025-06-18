import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Group.dart';
import '../dynamo/group_service.dart';

class GroupSelectionProvider extends ChangeNotifier {
  Group? _selectedGroup;
  bool _isPersonalMode = false;
  List<Group> _groups = [];
  bool _isLoading = false;
  String? _currentUserId;

  // SharedPreferences keys
  static const String _selectedGroupIdKey = 'selected_group_id';
  static const String _isPersonalModeKey = 'is_personal_mode';

  // Getters
  Group? get selectedGroup => _selectedGroup;
  bool get isPersonalMode => _isPersonalMode;
  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get currentUserId => _currentUserId;

  // Get display name for current selection
  String get currentSelectionName {
    if (_isPersonalMode) {
      return 'Personal';
    }
    return _selectedGroup?.name ?? 'No Group Selected';
  }

  // Check if user has any groups
  bool get hasGroups => _groups.isNotEmpty;

  GroupSelectionProvider() {
    _initialize();
  }

  /// Initialize the provider by loading user ID, groups, and restoring saved state
  Future<void> _initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get current user ID
      final user = await Amplify.Auth.getCurrentUser();
      _currentUserId = user.userId;

      // Load user's groups
      await _loadGroups();

      // Restore saved state
      await _restoreState();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ GroupSelectionProvider initialization failed: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load user's groups from the backend
  Future<void> _loadGroups() async {
    try {
      _groups = await GroupService.getUserGroups();
      debugPrint('✅ Loaded ${_groups.length} groups for user $_currentUserId');
    } catch (e) {
      debugPrint('❌ Failed to load groups: $e');
      _groups = [];
    }
  }

  /// Restore saved state from SharedPreferences
  Future<void> _restoreState() async {
    if (_currentUserId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userSpecificGroupKey = '${_currentUserId}_$_selectedGroupIdKey';
      final userSpecificModeKey = '${_currentUserId}_$_isPersonalModeKey';

      final savedGroupId = prefs.getString(userSpecificGroupKey);
      final savedIsPersonalMode = prefs.getBool(userSpecificModeKey) ?? false;

      if (savedIsPersonalMode) {
        // Restore personal mode
        _isPersonalMode = true;
        _selectedGroup = null;
        debugPrint('✅ Restored personal mode for user $_currentUserId');
      } else if (savedGroupId != null) {
        // Try to find and restore the saved group
        final savedGroup = _groups.firstWhere(
          (group) => group.id == savedGroupId,
          orElse: () => Group(id: '', name: '', ownerId: ''),
        );

        if (savedGroup.id.isNotEmpty) {
          _selectedGroup = savedGroup;
          _isPersonalMode = false;
          debugPrint('✅ Restored group selection: ${savedGroup.name} for user $_currentUserId');
        } else {
          // Saved group no longer exists, fall back to default
          _setDefaultSelection();
        }
      } else {
        // No saved state, set default
        _setDefaultSelection();
      }
    } catch (e) {
      debugPrint('❌ Failed to restore state: $e');
      _setDefaultSelection();
    }
  }

  /// Set default selection (personal mode if no groups, first group otherwise)
  void _setDefaultSelection() {
    if (_groups.isEmpty) {
      _isPersonalMode = true;
      _selectedGroup = null;
      debugPrint('✅ Set default to personal mode (no groups available)');
    } else {
      _isPersonalMode = false;
      _selectedGroup = _groups.first;
      debugPrint('✅ Set default to first group: ${_selectedGroup?.name}');
    }
  }

  /// Save current state to SharedPreferences
  Future<void> _saveState() async {
    if (_currentUserId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userSpecificGroupKey = '${_currentUserId}_$_selectedGroupIdKey';
      final userSpecificModeKey = '${_currentUserId}_$_isPersonalModeKey';

      if (_isPersonalMode) {
        await prefs.setBool(userSpecificModeKey, true);
        await prefs.remove(userSpecificGroupKey);
        debugPrint('✅ Saved personal mode for user $_currentUserId');
      } else if (_selectedGroup != null) {
        await prefs.setBool(userSpecificModeKey, false);
        await prefs.setString(userSpecificGroupKey, _selectedGroup!.id);
        debugPrint('✅ Saved group selection: ${_selectedGroup!.name} for user $_currentUserId');
      }
    } catch (e) {
      debugPrint('❌ Failed to save state: $e');
    }
  }

  /// Select a specific group
  Future<void> selectGroup(Group group) async {
    if (_selectedGroup?.id == group.id && !_isPersonalMode) return;

    _selectedGroup = group;
    _isPersonalMode = false;
    await _saveState();
    notifyListeners();
    debugPrint('✅ Selected group: ${group.name}');
  }

  /// Select personal mode (all groups aggregated)
  Future<void> selectPersonalMode() async {
    if (_isPersonalMode) return;

    _selectedGroup = null;
    _isPersonalMode = true;
    await _saveState();
    notifyListeners();
    debugPrint('✅ Selected personal mode');
  }

  /// Refresh groups from backend and update state if needed
  Future<void> refreshGroups() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _loadGroups();

      // Check if currently selected group still exists
      if (!_isPersonalMode && _selectedGroup != null) {
        final groupStillExists = _groups.any((group) => group.id == _selectedGroup!.id);
        if (!groupStillExists) {
          debugPrint('⚠️ Currently selected group no longer exists, switching to default');
          _setDefaultSelection();
          await _saveState();
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to refresh groups: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear all saved state (useful for logout)
  Future<void> clearState() async {
    if (_currentUserId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userSpecificGroupKey = '${_currentUserId}_$_selectedGroupIdKey';
      final userSpecificModeKey = '${_currentUserId}_$_isPersonalModeKey';

      await prefs.remove(userSpecificGroupKey);
      await prefs.remove(userSpecificModeKey);
      debugPrint('✅ Cleared group selection state for user $_currentUserId');
    } catch (e) {
      debugPrint('❌ Failed to clear state: $e');
    }
  }

  /// Reset provider state (useful for user switching)
  void reset() {
    _selectedGroup = null;
    _isPersonalMode = false;
    _groups = [];
    _isLoading = false;
    _currentUserId = null;
    notifyListeners();
  }

  /// Reinitialize the provider for a new user (useful after login)
  Future<void> reinitialize() async {
    try {
      debugPrint('🔄 Reinitializing GroupSelectionProvider for new user...');

      // Reset current state first
      reset();

      // Initialize with new user data
      await _initialize();

      debugPrint('✅ GroupSelectionProvider reinitialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to reinitialize GroupSelectionProvider: $e');
      // Ensure we're in a clean state even if initialization fails
      reset();
    }
  }
}
