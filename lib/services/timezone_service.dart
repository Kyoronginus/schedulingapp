import 'package:flutter/foundation.dart';
import 'package:amplify_core/amplify_core.dart';

class TimezoneService {
  /// Convert local DateTime to UTC for storage
  static TemporalDateTime localToUtc(DateTime localDateTime) {
    final utcDateTime = localDateTime.toUtc();
    return TemporalDateTime(utcDateTime);
  }

  /// Convert UTC TemporalDateTime to local DateTime for display
  static DateTime utcToLocal(TemporalDateTime utcTemporalDateTime) {
    final utcDateTime = utcTemporalDateTime.getDateTimeInUtc();
    return utcDateTime.toLocal();
  }

  /// Get current local time as TemporalDateTime in UTC for storage
  static TemporalDateTime nowUtc() {
    return TemporalDateTime(DateTime.now().toUtc());
  }

  /// Get current local time as DateTime
  static DateTime nowLocal() {
    return DateTime.now();
  }

  /// Format DateTime for display in local timezone
  static String formatLocalDateTime(TemporalDateTime utcTemporalDateTime, {String pattern = 'yyyy-MM-dd HH:mm'}) {
    final localDateTime = utcToLocal(utcTemporalDateTime);
    // You can use intl package for more sophisticated formatting
    return '${localDateTime.year.toString().padLeft(4, '0')}-'
           '${localDateTime.month.toString().padLeft(2, '0')}-'
           '${localDateTime.day.toString().padLeft(2, '0')} '
           '${localDateTime.hour.toString().padLeft(2, '0')}:'
           '${localDateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Format time only for display in local timezone
  static String formatLocalTime(TemporalDateTime utcTemporalDateTime) {
    final localDateTime = utcToLocal(utcTemporalDateTime);
    return '${localDateTime.hour.toString().padLeft(2, '0')}:'
           '${localDateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Format date only for display in local timezone
  static String formatLocalDate(TemporalDateTime utcTemporalDateTime) {
    final localDateTime = utcToLocal(utcTemporalDateTime);
    return '${localDateTime.year.toString().padLeft(4, '0')}-'
           '${localDateTime.month.toString().padLeft(2, '0')}-'
           '${localDateTime.day.toString().padLeft(2, '0')}';
  }

  /// Check if a UTC time is in the past relative to local time
  static bool isInPast(TemporalDateTime utcTemporalDateTime) {
    final localDateTime = utcToLocal(utcTemporalDateTime);
    return localDateTime.isBefore(DateTime.now());
  }

  /// Check if a UTC time is today in local timezone
  static bool isToday(TemporalDateTime utcTemporalDateTime) {
    final localDateTime = utcToLocal(utcTemporalDateTime);
    final now = DateTime.now();
    return localDateTime.year == now.year &&
           localDateTime.month == now.month &&
           localDateTime.day == now.day;
  }

  /// Get time difference from now in local timezone
  static Duration getDifferenceFromNow(TemporalDateTime utcTemporalDateTime) {
    final localDateTime = utcToLocal(utcTemporalDateTime);
    return localDateTime.difference(DateTime.now());
  }

  /// Create TemporalDateTime from local date and time components
  static TemporalDateTime createFromLocalComponents(
    int year, int month, int day, int hour, int minute, [int second = 0]
  ) {
    final localDateTime = DateTime(year, month, day, hour, minute, second);
    return localToUtc(localDateTime);
  }

  /// Validate that a local time is in the future
  static bool isLocalTimeInFuture(DateTime localDateTime) {
    return localDateTime.isAfter(DateTime.now());
  }

  /// Get timezone offset string for debugging
  static String getTimezoneOffset() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60);
    final sign = offset.isNegative ? '-' : '+';
    return '$sign${hours.abs().toString().padLeft(2, '0')}:${minutes.abs().toString().padLeft(2, '0')}';
  }

  /// Log timezone information for debugging
  static void logTimezoneInfo() {
    debugPrint('🌍 Timezone Info:');
    debugPrint('  - Local timezone offset: ${getTimezoneOffset()}');
    debugPrint('  - Current local time: ${DateTime.now()}');
    debugPrint('  - Current UTC time: ${DateTime.now().toUtc()}');
  }
}
