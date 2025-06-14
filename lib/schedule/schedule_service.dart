import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';
import '../models/Schedule.dart';
import 'schedule_extensions.dart';
import '../dynamo/group_service.dart';
import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';
import '../services/timezone_service.dart';

class ScheduleService {
  static Future<void> createSchedule(Schedule schedule) async {
    try {
      // Validate schedule data
      if (schedule.user == null || schedule.user!.id.isEmpty) {
        debugPrint('❌ ScheduleService: Invalid user data');
        throw Exception('Schedule must have a valid user');
      }
      if (schedule.group == null || schedule.group!.id.isEmpty) {
        debugPrint('❌ ScheduleService: Invalid group data');
        throw Exception('Schedule must have a valid group');
      }

      debugPrint('🔍 ScheduleService: Creating schedule with userId: ${schedule.user!.id}, groupId: ${schedule.group!.id}');
      debugPrint('🔍 ScheduleService: Schedule title: "${schedule.title}"');

      // Convert schedule to input format
      Map<String, dynamic> scheduleInput;
      try {
        scheduleInput = schedule.toInput();
        debugPrint('🔍 ScheduleService: Schedule input: $scheduleInput');
      } catch (e) {
        debugPrint('❌ ScheduleService: Failed to convert schedule to input: $e');
        throw Exception('Failed to prepare schedule data: $e');
      }

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
          'input': scheduleInput,
        },
      );

      debugPrint('🔍 ScheduleService: Sending GraphQL mutation...');
      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        debugPrint('❌ ScheduleService: GraphQL errors: ${response.errors}');
        final errorMessages = response.errors.map((e) => e.message).join(', ');
        throw Exception('Failed to create schedule: $errorMessages');
      }

      final responseData = response.data;
      if (responseData == null) {
        debugPrint('❌ ScheduleService: No data returned from mutation');
        throw Exception('Failed to create schedule: No data returned from server');
      }

      debugPrint("✅ ScheduleService: Schedule created via API: $responseData");

      // Parse the response
      final Map<String, dynamic> scheduleJson;
      try {
        scheduleJson = jsonDecode(responseData);
      } catch (e) {
        debugPrint('❌ ScheduleService: Failed to parse response JSON: $e');
        throw Exception('Failed to parse server response: $e');
      }

      final createdScheduleData = scheduleJson['createSchedule'];
      if (createdScheduleData == null) {
        debugPrint('❌ ScheduleService: No createSchedule data in response');
        throw Exception('Invalid response from server');
      }

      final createdScheduleId = createdScheduleData['id'];
      if (createdScheduleId == null) {
        debugPrint('❌ ScheduleService: No schedule ID in response');
        throw Exception('No schedule ID returned from server');
      }

      debugPrint("✅ ScheduleService: Created schedule ID: $createdScheduleId");

      final createdSchedule = Schedule(
        id: createdScheduleId,
        title: schedule.title,
        description: schedule.description,
        location: schedule.location,
        startTime: schedule.startTime,
        endTime: schedule.endTime,
        user: schedule.user,
        group: schedule.group,
      );

      // Add notifications
      try {
        debugPrint('🔍 ScheduleService: Adding notifications...');
        // Wait a moment for the schedule to be available in the backend
        await Future.delayed(const Duration(milliseconds: 500));
        await NotificationService.addCreatedScheduleNotification(createdSchedule);

        // Use local timezone for notification timing calculations
        final startTimeLocal = TimezoneService.utcToLocal(createdSchedule.startTime);
        final now = DateTime.now();
        final timeDifference = startTimeLocal.difference(now);

        if (timeDifference.inHours > 24) {
          await NotificationService.addUpcomingScheduleNotification(createdSchedule);
        }
        else if (timeDifference.inHours > 1) {
          await NotificationService.addUpcomingScheduleNotification(createdSchedule);
        }
        debugPrint('✅ ScheduleService: Notifications added successfully');
      } catch (e) {
        debugPrint('⚠️ ScheduleService: Failed to add notifications (schedule still created): $e');
        // Don't throw here as the schedule was created successfully
      }

    } catch (e) {
      debugPrint('❌ ScheduleService: Failed to create schedule: $e');
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
