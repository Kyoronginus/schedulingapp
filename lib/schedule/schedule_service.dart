import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';

import '../models/Schedule.dart';
import 'schedule_extensions.dart';
import '../dynamo/group_service.dart';
import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';

class ScheduleService {
  static Future<void> createSchedule(Schedule schedule) async {
    try {
      // Use copyWith to ensure the schedule object has consistent data types
      final validatedSchedule = schedule.copyWith(
        title: schedule.title,
        description: schedule.description,
        startTime: schedule.startTime,
        endTime: schedule.endTime,
      );

      // Skip saving to DataStore for now since we're having foreign key issues
      // We'll just use the API directly

      // Then, save to API for cloud sync
      final request = GraphQLRequest<String>(
        document: '''
          mutation CreateSchedule(\$input: CreateScheduleInput!) {
            createSchedule(input: \$input) {
              id
              title
              startTime
              endTime
              description
              location
              userId
              groupId
            }
          }
        ''',
        variables: {
          'input': validatedSchedule.toInput(),
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.hasErrors) {
        throw Exception(response.errors.first.message);
      }
      debugPrint("✅ Schedule created: ${response.data}");

      // Create a notification for the new schedule
      await NotificationService.addCreatedScheduleNotification(validatedSchedule);

      // Create notifications for upcoming schedule (24h and 1h before)
      final startTime = validatedSchedule.startTime.getDateTimeInUtc();
      final now = DateTime.now();
      final timeDifference = startTime.difference(now);

      // If the schedule is more than 24 hours in the future, create a 24h notification
      if (timeDifference.inHours > 24) {
        await NotificationService.addUpcomingScheduleNotification(validatedSchedule);
      }
      // If the schedule is more than 1 hour in the future, create a 1h notification
      else if (timeDifference.inHours > 1) {
        await NotificationService.addUpcomingScheduleNotification(validatedSchedule);
      }
    } catch (e) {
      debugPrint('❌ Failed to create schedule: $e');
      rethrow;
    }
  }

  static Future<void> updateSchedule(Schedule schedule) async {
    try {
      final request = GraphQLRequest<String>(
        document: '''
          mutation UpdateSchedule(\$input: UpdateScheduleInput!) {
            updateSchedule(input: \$input) {
              id
              title
              startTime
              endTime
              description
              location
              userId
              groupId
            }
          }
        ''',
        variables: {
          'input': {
            'id': schedule.id,
            'title': schedule.title,
            'description': schedule.description,
            'location': schedule.location,
            'startTime': schedule.startTime.format(),
            'endTime': schedule.endTime.format(),
            '_version': 1, // This might need to be adjusted based on your schema
          },
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.hasErrors) {
        throw Exception(response.errors.first.message);
      }
      debugPrint("✅ Schedule updated: ${response.data}");
    } catch (e) {
      debugPrint('❌ Failed to update schedule: $e');
      rethrow;
    }
  }

  static Future<void> deleteSchedule(String scheduleId) async {
    try {
      final request = GraphQLRequest<String>(
        document: '''
          mutation DeleteSchedule(\$input: DeleteScheduleInput!) {
            deleteSchedule(input: \$input) {
              id
            }
          }
        ''',
        variables: {
          'input': {
            'id': scheduleId,
          },
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.hasErrors) {
        throw Exception(response.errors.first.message);
      }
      debugPrint("✅ Schedule deleted: ${response.data}");
    } catch (e) {
      debugPrint('❌ Failed to delete schedule: $e');
      rethrow;
    }
  }

  static Future<List<Schedule>> getUserSchedules(String userId) async {
    try {
      final request = GraphQLRequest<String>(
        document: '''
          query ListSchedules(\$filter: ModelScheduleFilterInput) {
            listSchedules(filter: \$filter) {
              items {
                id
                title
                startTime
                endTime
                description
                location
                userId
                groupId
              }
            }
          }
        ''',
        variables: {
          'filter': {
            'userId': {'eq': userId},
          },
        },
      );

      final response = await Amplify.API.query(request: request).response;
      if (response.hasErrors) {
        throw Exception(response.errors.first.message);
      }

      final data = response.data;
      if (data == null) return [];

      final schedules = ScheduleListExtension.listFromJson(data);
      return schedules;
    } catch (e) {
      debugPrint('❌ Failed to fetch schedules: $e');
      rethrow;
    }
  }

  static Future<List<Schedule>> getGroupSchedules(String groupId) async {
    try {
      final request = GraphQLRequest<String>(
        document: '''
          query ListSchedules(\$filter: ModelScheduleFilterInput) {
            listSchedules(filter: \$filter) {
              items {
                id
                title
                startTime
                endTime
                description
                location
                userId
                groupId
              }
            }
          }
        ''',
        variables: {
          'filter': {
            'groupId': {'eq': groupId},
          },
        },
      );

      final response = await Amplify.API.query(request: request).response;
      if (response.hasErrors) {
        throw Exception(response.errors.first.message);
      }

      final data = response.data;
      if (data == null) return [];

      final schedules = ScheduleListExtension.listFromJson(data);
      return schedules;
    } catch (e) {
      debugPrint('❌ Failed to fetch group schedules: $e');
      rethrow;
    }
  }

  // Helper method to ensure related entities exist in DataStore
  static Future<void> _ensureRelatedEntitiesExist(Schedule schedule) async {
    try {
      // For now, we'll just log that we're trying to ensure related entities exist
      // This is a simplified version that doesn't try to create the related entities
      debugPrint('Ensuring related entities exist for schedule: ${schedule.id}');

      // In a real implementation, we would check if the User and Group exist
      // and create them if they don't, but for now we'll just skip this step
      // since we're having issues with the foreign key constraints
    } catch (e) {
      debugPrint('❌ Error ensuring related entities exist: $e');
      // Continue anyway - we'll try to save the schedule
    }
  }

  static Future<List<Schedule>> loadAllSchedules() async {
    try {
      final groups = await GroupService.getUserGroups();
      debugPrint('🧩 所属グループ数: ${groups.length}');

      final allSchedules = <Schedule>[];

      for (final group in groups) {
        debugPrint('📅 ${group.name}（ID: ${group.id}）のスケジュールを取得中...');
        final groupSchedules =
            await ScheduleService.getGroupSchedules(group.id);
        debugPrint('✅ ${groupSchedules.length} 件取得');
        allSchedules.addAll(groupSchedules);
      }
      debugPrint('📦 スケジュール総数: ${allSchedules.length}');

      void debugScheduleList(List<Schedule> schedules) {
        for (final s in schedules) {
          debugPrint(
              '📅 Schedule: ${s.title}, start=${s.startTime.getDateTimeInUtc().toLocal()}');
        }
      }

      debugScheduleList(allSchedules);

      return allSchedules;
    } catch (e) {
      debugPrint('❌ Failed to load all schedules: $e');
      rethrow;
    }
  }
}
