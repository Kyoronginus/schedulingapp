import 'dart:convert';
import '../models/Schedule.dart';
import 'package:amplify_core/amplify_core.dart';
import '../models/User.dart'; // Import User class
import '../models/Group.dart'; // Import Group class

extension ScheduleExtension on Schedule {
  Map<String, dynamic> toInput() {
    // Validate that required foreign keys are present
    final userId = user?.id;
    final groupId = group?.id;

    if (userId == null || userId.isEmpty) {
      throw Exception('Schedule must have a valid userId');
    }
    if (groupId == null || groupId.isEmpty) {
      throw Exception('Schedule must have a valid groupId');
    }

    return {
      'title': title,
      'description': description,
      'location': location,
      'startTime': startTime.format(),
      'endTime': endTime.format(),
      'userId': userId,
      'groupId': groupId,
    };
  }
}

extension ScheduleListExtension on Schedule {
  static List<Schedule> listFromJson(String jsonString) {
    final decoded = jsonDecode(jsonString);

    final items = decoded['listSchedules']?['items'] ?? [];

    return List<Schedule>.from(
      items.map((item) => Schedule.fromJson(item)),
    );
  }
}

extension ScheduleExtensions on Schedule {
  // ビジネスロジックやヘルパーメソッドを追加
  String get formattedStartTime {
    return startTime.format();
  }

  bool get isGroupSchedule {
    return group != null;
  }

  // モデルコピー用メソッド
  Schedule copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    TemporalDateTime? startTime,
    TemporalDateTime? endTime,
    User? user,
    Group? group,
  }) {
    return Schedule(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      user: user ?? this.user,
      group: group ?? this.group,
    );
  }
}
