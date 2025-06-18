import '../models/Schedule.dart';
import '../services/timezone_service.dart';
import 'package:flutter/foundation.dart';

/// Utility class for detecting schedule conflicts between different groups
class ScheduleConflictDetector {
  /// Detects conflicts for schedules on a specific date
  /// Returns a set of group IDs that have conflicted schedules
  static Set<String> detectConflictsForDate(List<Schedule> schedulesForDate) {
    if (schedulesForDate.length < 2) {
      return <String>{};
    }

    final conflictedGroupIds = <String>{};

    // Group schedules by their group ID
    final schedulesByGroup = <String, List<Schedule>>{};
    for (final schedule in schedulesForDate) {
      final groupId = schedule.group?.id;
      if (groupId != null) {
        schedulesByGroup.putIfAbsent(groupId, () => []).add(schedule);
      }
    }

    // Only check conflicts if there are schedules from multiple groups
    if (schedulesByGroup.keys.length < 2) {
      return <String>{};
    }

    // Check for conflicts between different groups
    final allSchedules = schedulesForDate.toList();
    
    for (int i = 0; i < allSchedules.length; i++) {
      for (int j = i + 1; j < allSchedules.length; j++) {
        final schedule1 = allSchedules[i];
        final schedule2 = allSchedules[j];
        
        // Only check conflicts between different groups
        if (schedule1.group?.id != schedule2.group?.id) {
          if (schedulesOverlap(schedule1, schedule2)) {
            // Determine which schedule was created later
            final laterSchedule = _getLaterCreatedSchedule(schedule1, schedule2);
            if (laterSchedule != null && laterSchedule.group?.id != null) {
              conflictedGroupIds.add(laterSchedule.group!.id);
            }
          }
        }
      }
    }

    return conflictedGroupIds;
  }

  /// Checks if two schedules have overlapping time periods
  static bool schedulesOverlap(Schedule schedule1, Schedule schedule2) {
    try {
      // Convert to local time for comparison
      final start1 = TimezoneService.utcToLocal(schedule1.startTime);
      final end1 = TimezoneService.utcToLocal(schedule1.endTime);
      final start2 = TimezoneService.utcToLocal(schedule2.startTime);
      final end2 = TimezoneService.utcToLocal(schedule2.endTime);

      // Two time periods overlap if: start1 < end2 AND start2 < end1
      return start1.isBefore(end2) && start2.isBefore(end1);
    } catch (e) {
      debugPrint('Error checking schedule overlap: $e');
      return false;
    }
  }

  /// Returns the schedule that was created later, or null if creation times are unavailable
  static Schedule? _getLaterCreatedSchedule(Schedule schedule1, Schedule schedule2) {
    final createdAt1 = schedule1.createdAt;
    final createdAt2 = schedule2.createdAt;

    if (createdAt1 == null || createdAt2 == null) {
      debugPrint('Warning: Schedule missing createdAt timestamp for conflict detection');
      return null;
    }

    try {
      final time1 = createdAt1.getDateTimeInUtc();
      final time2 = createdAt2.getDateTimeInUtc();
      
      return time1.isAfter(time2) ? schedule1 : schedule2;
    } catch (e) {
      debugPrint('Error comparing schedule creation times: $e');
      return null;
    }
  }

  /// Detects conflicts across all dates in a grouped schedule map
  /// Returns a map of date to conflicted group IDs
  static Map<DateTime, Set<String>> detectAllConflicts(
    Map<DateTime, List<Schedule>> groupedSchedules,
  ) {
    final conflicts = <DateTime, Set<String>>{};
    
    for (final entry in groupedSchedules.entries) {
      final date = entry.key;
      final schedules = entry.value;
      
      final conflictedGroups = detectConflictsForDate(schedules);
      if (conflictedGroups.isNotEmpty) {
        conflicts[date] = conflictedGroups;
      }
    }
    
    return conflicts;
  }

  /// Checks if a specific group has conflicts on a given date
  static bool groupHasConflictOnDate(
    String groupId,
    DateTime date,
    Map<DateTime, Set<String>> conflicts,
  ) {
    final conflictedGroups = conflicts[date];
    return conflictedGroups?.contains(groupId) ?? false;
  }
}

/// Data class to hold conflict information for a specific date
class ConflictInfo {
  final Set<String> conflictedGroupIds;
  final bool hasConflicts;
  
  ConflictInfo({required this.conflictedGroupIds}) 
    : hasConflicts = conflictedGroupIds.isNotEmpty;
  
  ConflictInfo.empty() 
    : conflictedGroupIds = <String>{},
      hasConflicts = false;
}
