import 'package:flutter/material.dart';
import '../models/models.dart';

class DailySleepStat {
  final DateTime date;
  final double totalHours;
  final TimeOfDay? bedtime;
  final TimeOfDay? wakeTime;
  final int sessionCount;

  DailySleepStat({
    required this.date,
    required this.totalHours,
    this.bedtime,
    this.wakeTime,
    this.sessionCount = 0,
  });
}

class SleepStatsService {
  /// Get sleep duration in hours for a single record.
  static double durationHours(SleepRecord r) {
    final start = DateTime(
      r.sleepDate.year,
      r.sleepDate.month,
      r.sleepDate.day,
      r.sleepTime.hour,
      r.sleepTime.minute,
    );
    final end = DateTime(
      r.wakeDate.year,
      r.wakeDate.month,
      r.wakeDate.day,
      r.wakeTime.hour,
      r.wakeTime.minute,
    );
    return end.difference(start).inMinutes / 60.0;
  }

  /// Convert TimeOfDay to minutes since midnight, treating
  /// times before 6 AM as "next day" for bedtime averaging.
  static double _bedtimeMinutes(TimeOfDay t) {
    final m = t.hour * 60 + t.minute;
    // If bedtime is before 6 AM, treat as past midnight (add 24h)
    return m < 360 ? m + 1440.0 : m.toDouble();
  }

  /// Build daily stats for a range of dates.
  static List<DailySleepStat> dailyStats(
    Map<DateTime, List<SleepRecord>> sleepData,
    int days,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final stats = <DailySleepStat>[];

    for (int i = days - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final key = DateTime(date.year, date.month, date.day);
      final records = sleepData[key] ?? [];

      double total = 0;
      for (final r in records) {
        total += durationHours(r);
      }

      stats.add(
        DailySleepStat(
          date: date,
          totalHours: total,
          bedtime: records.isNotEmpty ? records.first.sleepTime : null,
          wakeTime: records.isNotEmpty ? records.last.wakeTime : null,
          sessionCount: records.length,
        ),
      );
    }
    return stats;
  }

  /// Average sleep duration over the given daily stats.
  static double averageDuration(List<DailySleepStat> stats) {
    final withSleep = stats.where((s) => s.totalHours > 0).toList();
    if (withSleep.isEmpty) return 0;
    return withSleep.fold(0.0, (sum, s) => sum + s.totalHours) /
        withSleep.length;
  }

  /// Average bedtime as TimeOfDay.
  static TimeOfDay? averageBedtime(List<DailySleepStat> stats) {
    final bedtimes = stats
        .where((s) => s.bedtime != null)
        .map((s) => s.bedtime!)
        .toList();
    if (bedtimes.isEmpty) return null;
    final avgMinutes =
        bedtimes.fold(0.0, (sum, t) => sum + _bedtimeMinutes(t)) /
        bedtimes.length;
    final normalized = avgMinutes >= 1440 ? avgMinutes - 1440 : avgMinutes;
    return TimeOfDay(
      hour: normalized.toInt() ~/ 60,
      minute: normalized.toInt() % 60,
    );
  }

  /// Average wake time as TimeOfDay.
  static TimeOfDay? averageWakeTime(List<DailySleepStat> stats) {
    final wakeTimes = stats
        .where((s) => s.wakeTime != null)
        .map((s) => s.wakeTime!)
        .toList();
    if (wakeTimes.isEmpty) return null;
    final avgMinutes =
        wakeTimes.fold(0.0, (sum, t) => sum + t.hour * 60 + t.minute) /
        wakeTimes.length;
    return TimeOfDay(
      hour: avgMinutes.toInt() ~/ 60,
      minute: avgMinutes.toInt() % 60,
    );
  }

  /// Total nights with at least one sleep record.
  static int totalNightsTracked(Map<DateTime, List<SleepRecord>> data) {
    return data.values.where((v) => v.isNotEmpty).length;
  }

  /// Best and worst night (by duration) from daily stats.
  static DailySleepStat? bestNight(List<DailySleepStat> stats) {
    final withSleep = stats.where((s) => s.totalHours > 0).toList();
    if (withSleep.isEmpty) return null;
    return withSleep.reduce((a, b) => a.totalHours >= b.totalHours ? a : b);
  }

  static DailySleepStat? worstNight(List<DailySleepStat> stats) {
    final withSleep = stats.where((s) => s.totalHours > 0).toList();
    if (withSleep.isEmpty) return null;
    return withSleep.reduce((a, b) => a.totalHours <= b.totalHours ? a : b);
  }

  /// Sleep consistency score (0-100). Lower std deviation = higher score.
  static double consistencyScore(List<DailySleepStat> stats) {
    final withSleep = stats.where((s) => s.totalHours > 0).toList();
    if (withSleep.length < 2) return 100;
    final avg = averageDuration(withSleep);
    final variance =
        withSleep.fold(0.0, (sum, s) {
          final diff = s.totalHours - avg;
          return sum + diff * diff;
        }) /
        withSleep.length;
    final stdDev = variance > 0 ? _sqrt(variance) : 0.0;
    // Score: 100 when stdDev=0, drops ~10 pts per hour of deviation
    return (100 - stdDev * 10).clamp(0, 100);
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    double x = v;
    for (int i = 0; i < 20; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }

  /// Format hours as "Xh Ym".
  static String formatHours(double hours) {
    final h = hours.toInt();
    final m = ((hours - h) * 60).round();
    return '${h}h ${m}m';
  }

  /// Format TimeOfDay as "HH:MM".
  static String formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// Weekly comparison: this week avg vs last week avg.
  static (double thisWeek, double lastWeek) weeklyComparison(
    Map<DateTime, List<SleepRecord>> sleepData,
  ) {
    final last14 = dailyStats(sleepData, 14);
    final thisWeekStats = last14.sublist(7);
    final lastWeekStats = last14.sublist(0, 7);
    return (averageDuration(thisWeekStats), averageDuration(lastWeekStats));
  }

  /// Count activity records in a date range.
  static int countActivitiesInRange<T>(
    List<T> records,
    DateTime Function(T) getDate,
    int days,
  ) {
    final now = DateTime.now();
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days));
    return records.where((r) {
      final d = getDate(r);
      return d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff);
    }).length;
  }
}
