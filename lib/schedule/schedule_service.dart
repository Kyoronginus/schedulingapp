import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Schedule.dart';
import 'schedule_extensions.dart';
import '../dynamo/group_service.dart';
import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';

class ScheduleService {
  static Future<void> createSchedule(Schedule schedule) async {
    try {
      if (schedule.user == null || schedule.user!.id.isEmpty) {
        throw Exception('Schedule must have a valid user');
      }
      if (schedule.group == null || schedule.group!.id.isEmpty) {
        throw Exception('Schedule must have a valid group');
      }

      debugPrint('Creating schedule with userId: ${schedule.user!.id}, groupId: ${schedule.group!.id}');

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
              createdAt
              updatedAt
            }
          }
        ''',
        variables: {
          'input': schedule.toInput(),
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.hasErrors) {
        throw Exception(response.errors.first.message);
      }

      debugPrint("✅ Schedule created via API: ${response.data}");
      debugPrint("📱 Schedule will be synced to DataStore automatically");

      await NotificationService.addCreatedScheduleNotification(schedule);

      final startTime = schedule.startTime.getDateTimeInUtc();
      final now = DateTime.now();
      final timeDifference = startTime.difference(now);

      if (timeDifference.inHours > 24) {
        await NotificationService.addUpcomingScheduleNotification(schedule);
      }
      else if (timeDifference.inHours > 1) {
        await NotificationService.addUpcomingScheduleNotification(schedule);
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
            'userId': schedule.user?.id,
            'groupId': schedule.group?.id,
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
