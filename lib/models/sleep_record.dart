import 'package:flutter/material.dart';

class SleepRecord {
  final DateTime sleepDate;
  final TimeOfDay sleepTime;
  final DateTime wakeDate;
  final TimeOfDay wakeTime;

  SleepRecord({
    required this.sleepDate,
    required this.sleepTime,
    required this.wakeDate,
    required this.wakeTime,
  });

  DateTime get date => sleepDate;

  Map<String, dynamic> toJson() {
    return {
      'sleepDate': sleepDate.toIso8601String(),
      'sleepTime': '${sleepTime.hour}:${sleepTime.minute}',
      'wakeDate': wakeDate.toIso8601String(),
      'wakeTime': '${wakeTime.hour}:${wakeTime.minute}',
    };
  }

  factory SleepRecord.fromJson(Map<String, dynamic> json) {
    final sleepParts = (json['sleepTime'] as String).split(':');
    final wakeParts = (json['wakeTime'] as String).split(':');
    return SleepRecord(
      sleepDate: DateTime.parse(json['sleepDate'] ?? json['date']),
      sleepTime: TimeOfDay(
        hour: int.parse(sleepParts[0]),
        minute: int.parse(sleepParts[1]),
      ),
      wakeDate: DateTime.parse(json['wakeDate'] ?? json['date']),
      wakeTime: TimeOfDay(
        hour: int.parse(wakeParts[0]),
        minute: int.parse(wakeParts[1]),
      ),
    );
  }
}
