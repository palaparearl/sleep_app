import 'package:flutter/material.dart';

class MedicineRecord {
  final DateTime startDate;
  final TimeOfDay startTime;
  final DateTime endDate;
  final TimeOfDay endTime;

  MedicineRecord({
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    'startTime': '${startTime.hour}:${startTime.minute}',
    'endDate': endDate.toIso8601String(),
    'endTime': '${endTime.hour}:${endTime.minute}',
  };

  factory MedicineRecord.fromJson(Map<String, dynamic> json) {
    final startParts = (json['startTime'] as String).split(':');
    final endParts = (json['endTime'] as String).split(':');
    return MedicineRecord(
      startDate: DateTime.parse(json['startDate']),
      startTime: TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      ),
      endDate: DateTime.parse(json['endDate']),
      endTime: TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      ),
    );
  }
}
