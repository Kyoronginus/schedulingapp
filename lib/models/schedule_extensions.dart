import 'dart:convert';
import 'Schedule.dart';
import 'package:amplify_core/amplify_core.dart';
import 'User.dart'; // Import User class
import 'Group.dart'; // Import Group class

extension ScheduleExtension on Schedule {
  Map<String, dynamic> toInput() {
    return {
      'title': title,
      'description': description,
      'startTime': startTime.format(),
      'endTime': endTime.format(),
      'userId': user?.id,
      'groupId': group?.id,
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
    TemporalDateTime? startTime,
    TemporalDateTime? endTime,
    User? user,
    Group? group,
  }) {
    return Schedule(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      user: user ?? this.user,
      group: group ?? this.group,
    );
  }
}
