import 'package:flutter/material.dart';

String formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String calculateDuration(
  DateTime sleepDate,
  TimeOfDay sleepTime,
  DateTime wakeDate,
  TimeOfDay wakeTime,
) {
  final start = DateTime(
    sleepDate.year,
    sleepDate.month,
    sleepDate.day,
    sleepTime.hour,
    sleepTime.minute,
  );
  final end = DateTime(
    wakeDate.year,
    wakeDate.month,
    wakeDate.day,
    wakeTime.hour,
    wakeTime.minute,
  );
  final duration = end.difference(start);
  final hours = duration.inMinutes ~/ 60;
  final minutes = duration.inMinutes % 60;
  return '${hours}h ${minutes}m';
}

String getDayName(DateTime date) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return days[date.weekday - 1];
}
