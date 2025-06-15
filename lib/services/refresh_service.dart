import 'dart:async';

/// Service to handle automatic refresh notifications across the app
/// When data changes occur (like creating schedules, updating profile, etc.),
/// this service notifies all listening screens to refresh their content
class RefreshService {
  static final RefreshService _instance = RefreshService._internal();
  factory RefreshService() => _instance;
  RefreshService._internal();

  // Stream controllers for different types of data changes
  final StreamController<void> _scheduleChangesController = StreamController<void>.broadcast();
  final StreamController<void> _groupChangesController = StreamController<void>.broadcast();
  final StreamController<void> _profileChangesController = StreamController<void>.broadcast();
  final StreamController<void> _generalChangesController = StreamController<void>.broadcast();

  // Streams that screens can listen to
  Stream<void> get scheduleChanges => _scheduleChangesController.stream;
  Stream<void> get groupChanges => _groupChangesController.stream;
  Stream<void> get profileChanges => _profileChangesController.stream;
  Stream<void> get generalChanges => _generalChangesController.stream;

  // Methods to trigger refresh notifications
  void notifyScheduleChange() {
    _scheduleChangesController.add(null);
    _generalChangesController.add(null);
  }

  void notifyGroupChange() {
    _groupChangesController.add(null);
    _generalChangesController.add(null);
  }

  void notifyProfileChange() {
    _profileChangesController.add(null);
    _generalChangesController.add(null);
  }

  void notifyGeneralChange() {
    _generalChangesController.add(null);
  }

  // Dispose method to clean up resources
  void dispose() {
    _scheduleChangesController.close();
    _groupChangesController.close();
    _profileChangesController.close();
    _generalChangesController.close();
  }
}
