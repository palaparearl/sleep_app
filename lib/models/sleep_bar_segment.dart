import 'package:flutter/material.dart';
import 'sleep_record.dart';

class SleepBarSegment {
  final SleepRecord record;
  final TimeOfDay start;
  final TimeOfDay end;

  SleepBarSegment({
    required this.record,
    required this.start,
    required this.end,
  });
}
