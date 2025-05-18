import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Schedule.dart';
import '../models/schedule_extensions.dart';
import '../models/Group.dart';
import '../models/User.dart';
import '../dynamo/group_service.dart';
import 'package:amplify_api/amplify_api.dart';

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

      final request = GraphQLRequest<String>(
        document: '''
          mutation CreateSchedule(\$input: CreateScheduleInput!) {
            createSchedule(input: \$input) {
              id
              title
              startTime
              endTime
              description
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
      print("✅ Schedule created: ${response.data}");
    } catch (e) {
      print('❌ Failed to create schedule: $e');
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
      print('❌ Failed to fetch schedules: $e');
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
      print('❌ Failed to fetch group schedules: $e');
      rethrow;
    }
  }

  static Future<List<Schedule>> loadAllSchedules() async {
    try {
      final groups = await GroupService.getUserGroups();
      print('🧩 所属グループ数: ${groups.length}');

      final allSchedules = <Schedule>[];

      for (final group in groups) {
        print('📅 ${group.name}（ID: ${group.id}）のスケジュールを取得中...');
        final groupSchedules =
            await ScheduleService.getGroupSchedules(group.id);
        print('✅ ${groupSchedules.length} 件取得');
        allSchedules.addAll(groupSchedules);
      }
      print('📦 スケジュール総数: ${allSchedules.length}');

      void debugScheduleList(List<Schedule> schedules) {
        for (final s in schedules) {
          print(
              '📅 Schedule: ${s.title}, start=${s.startTime.getDateTimeInUtc().toLocal()}');
        }
      }

      debugScheduleList(allSchedules);

      return allSchedules;
    } catch (e) {
      print('❌ Failed to load all schedules: $e');
      rethrow;
    }
  }
}
