import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Schedule.dart';
import '../models/Schedule_extensions.dart';

import 'package:amplify_api/amplify_api.dart';

class ScheduleService {
  // スケジュールを作成
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

  // 自分のスケジュールを全部取得
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

      // ここでデータをモデルに変換する
      final schedules = ScheduleListExtension.listFromJson(data);
      return schedules;
    } catch (e) {
      print('❌ Failed to fetch schedules: $e');
      rethrow;
    }
  }

  // グループのスケジュールを取得
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
}
