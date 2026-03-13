import 'package:flutter/material.dart';
import '../models/models.dart';
import 'sleep_stats_service.dart';

class SleepInsight {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const SleepInsight({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

class SmartInsightsService {
  static List<SleepInsight> generateInsights({
    required Map<DateTime, List<SleepRecord>> sleepData,
    required List<CoffeeRecord> coffeeRecords,
    required List<AlcoholRecord> alcoholRecords,
    required List<MedicineRecord> medicineRecords,
  }) {
    final insights = <SleepInsight>[];
    final stats7 = SleepStatsService.dailyStats(sleepData, 7);
    final stats14 = SleepStatsService.dailyStats(sleepData, 14);
    final avg7 = SleepStatsService.averageDuration(stats7);
    final (thisWeek, lastWeek) = SleepStatsService.weeklyComparison(sleepData);
    final consistency = SleepStatsService.consistencyScore(stats7);
    final avgBedtime = SleepStatsService.averageBedtime(stats7);

    // No data check
    final daysWithSleep = stats7.where((s) => s.totalHours > 0).length;
    if (daysWithSleep == 0) {
      insights.add(
        const SleepInsight(
          icon: Icons.info_outline,
          color: Colors.grey,
          title: 'No sleep data yet',
          description:
              'Start logging your sleep to see personalized insights here.',
        ),
      );
      return insights;
    }

    // 1. Sleep duration assessment
    if (avg7 < 6) {
      insights.add(
        SleepInsight(
          icon: Icons.warning_amber_rounded,
          color: Colors.redAccent,
          title: 'Sleep deficit detected',
          description:
              'You averaged ${SleepStatsService.formatHours(avg7)} this week — well below the recommended 7–9 hours. Even small increases can improve focus and mood.',
        ),
      );
    } else if (avg7 < 7) {
      insights.add(
        SleepInsight(
          icon: Icons.info_outline,
          color: Colors.orange,
          title: 'Slightly below target',
          description:
              'Your average of ${SleepStatsService.formatHours(avg7)} is close but under the recommended 7–9 hours. Try going to bed 30 minutes earlier.',
        ),
      );
    } else if (avg7 <= 9) {
      insights.add(
        SleepInsight(
          icon: Icons.check_circle,
          color: Colors.green,
          title: 'Healthy sleep duration',
          description:
              'Great job! Your average of ${SleepStatsService.formatHours(avg7)} falls within the recommended 7–9 hour range.',
        ),
      );
    } else {
      insights.add(
        SleepInsight(
          icon: Icons.info_outline,
          color: Colors.orange,
          title: 'Oversleeping pattern',
          description:
              'Averaging ${SleepStatsService.formatHours(avg7)} per night. Consistently sleeping over 9 hours may indicate underlying issues.',
        ),
      );
    }

    // 2. Weekly trend
    if (lastWeek > 0) {
      final diff = thisWeek - lastWeek;
      if (diff > 0.5) {
        insights.add(
          SleepInsight(
            icon: Icons.trending_up,
            color: Colors.green,
            title: 'Improving trend',
            description:
                'You\'re sleeping ${SleepStatsService.formatHours(diff)} more per night than last week. Keep it up!',
          ),
        );
      } else if (diff < -0.5) {
        insights.add(
          SleepInsight(
            icon: Icons.trending_down,
            color: Colors.redAccent,
            title: 'Declining trend',
            description:
                'You\'re sleeping ${SleepStatsService.formatHours(-diff)} less per night than last week. Consider what changed.',
          ),
        );
      }
    }

    // 3. Consistency insight
    if (consistency < 50) {
      insights.add(
        const SleepInsight(
          icon: Icons.shuffle,
          color: Colors.redAccent,
          title: 'Irregular sleep pattern',
          description:
              'Your sleep times vary widely. A consistent schedule helps regulate your circadian rhythm and improves sleep quality.',
        ),
      );
    } else if (consistency >= 80) {
      insights.add(
        const SleepInsight(
          icon: Icons.verified,
          color: Colors.green,
          title: 'Consistent sleeper',
          description:
              'Your sleep schedule is very regular — this is great for your body\'s internal clock.',
        ),
      );
    }

    // 4. Late bedtime
    if (avgBedtime != null) {
      final bedMinutes = avgBedtime.hour * 60 + avgBedtime.minute;
      // Past midnight (0:00-3:59) or very late (after 1 AM)
      if (bedMinutes < 240 || bedMinutes > 60) {
        if (bedMinutes < 240) {
          insights.add(
            SleepInsight(
              icon: Icons.nightlight_round,
              color: Colors.deepPurple,
              title: 'Late bedtime',
              description:
                  'Your average bedtime is ${SleepStatsService.formatTime(avgBedtime)}. Going to bed before midnight can improve sleep quality.',
            ),
          );
        }
      }
    }

    // 5. Coffee correlation
    _addCoffeeInsight(insights, sleepData, coffeeRecords, stats7);

    // 6. Alcohol correlation
    _addAlcoholInsight(insights, sleepData, alcoholRecords, stats7);

    // 7. Weekend vs weekday pattern
    _addWeekendInsight(insights, stats14);

    // 8. Tracking encouragement
    if (daysWithSleep < 4) {
      insights.add(
        SleepInsight(
          icon: Icons.edit_calendar,
          color: Colors.teal,
          title: 'Track more consistently',
          description:
              'You logged sleep on $daysWithSleep of the last 7 days. More data means better insights.',
        ),
      );
    }

    return insights;
  }

  static void _addCoffeeInsight(
    List<SleepInsight> insights,
    Map<DateTime, List<SleepRecord>> sleepData,
    List<CoffeeRecord> coffeeRecords,
    List<DailySleepStat> stats7,
  ) {
    if (coffeeRecords.isEmpty) return;

    // Check if coffee days have shorter sleep
    double coffeeDaySleep = 0;
    int coffeeDayCount = 0;
    double noCoffeeDaySleep = 0;
    int noCoffeeDayCount = 0;

    for (final stat in stats7) {
      if (stat.totalHours == 0) continue;
      final d = DateTime(stat.date.year, stat.date.month, stat.date.day);
      final hadCoffee = coffeeRecords.any((r) {
        final rd = DateTime(
          r.startDate.year,
          r.startDate.month,
          r.startDate.day,
        );
        return rd == d;
      });
      if (hadCoffee) {
        coffeeDaySleep += stat.totalHours;
        coffeeDayCount++;
      } else {
        noCoffeeDaySleep += stat.totalHours;
        noCoffeeDayCount++;
      }
    }

    if (coffeeDayCount >= 2 && noCoffeeDayCount >= 2) {
      final coffeeAvg = coffeeDaySleep / coffeeDayCount;
      final noCoffeeAvg = noCoffeeDaySleep / noCoffeeDayCount;
      if (noCoffeeAvg - coffeeAvg > 0.5) {
        insights.add(
          SleepInsight(
            icon: Icons.coffee,
            color: Colors.brown,
            title: 'Coffee may affect your sleep',
            description:
                'On coffee days you slept ${SleepStatsService.formatHours(coffeeAvg)} vs ${SleepStatsService.formatHours(noCoffeeAvg)} on non-coffee days.',
          ),
        );
      }
    }
  }

  static void _addAlcoholInsight(
    List<SleepInsight> insights,
    Map<DateTime, List<SleepRecord>> sleepData,
    List<AlcoholRecord> alcoholRecords,
    List<DailySleepStat> stats7,
  ) {
    if (alcoholRecords.isEmpty) return;

    double alcoholDaySleep = 0;
    int alcoholDayCount = 0;
    double noAlcoholDaySleep = 0;
    int noAlcoholDayCount = 0;

    for (final stat in stats7) {
      if (stat.totalHours == 0) continue;
      final d = DateTime(stat.date.year, stat.date.month, stat.date.day);
      final hadAlcohol = alcoholRecords.any((r) {
        final rd = DateTime(
          r.startDate.year,
          r.startDate.month,
          r.startDate.day,
        );
        return rd == d;
      });
      if (hadAlcohol) {
        alcoholDaySleep += stat.totalHours;
        alcoholDayCount++;
      } else {
        noAlcoholDaySleep += stat.totalHours;
        noAlcoholDayCount++;
      }
    }

    if (alcoholDayCount >= 2 && noAlcoholDayCount >= 2) {
      final alcoholAvg = alcoholDaySleep / alcoholDayCount;
      final noAlcoholAvg = noAlcoholDaySleep / noAlcoholDayCount;
      if (noAlcoholAvg - alcoholAvg > 0.5) {
        insights.add(
          SleepInsight(
            icon: Icons.local_bar,
            color: Colors.redAccent,
            title: 'Alcohol may affect your sleep',
            description:
                'On alcohol days you slept ${SleepStatsService.formatHours(alcoholAvg)} vs ${SleepStatsService.formatHours(noAlcoholAvg)} without alcohol.',
          ),
        );
      }
    }
  }

  static void _addWeekendInsight(
    List<SleepInsight> insights,
    List<DailySleepStat> stats14,
  ) {
    double weekdayTotal = 0;
    int weekdayCount = 0;
    double weekendTotal = 0;
    int weekendCount = 0;

    for (final s in stats14) {
      if (s.totalHours == 0) continue;
      if (s.date.weekday >= 6) {
        weekendTotal += s.totalHours;
        weekendCount++;
      } else {
        weekdayTotal += s.totalHours;
        weekdayCount++;
      }
    }

    if (weekdayCount >= 3 && weekendCount >= 2) {
      final weekdayAvg = weekdayTotal / weekdayCount;
      final weekendAvg = weekendTotal / weekendCount;
      final diff = weekendAvg - weekdayAvg;
      if (diff > 0.75) {
        insights.add(
          SleepInsight(
            icon: Icons.weekend,
            color: Colors.blue,
            title: 'Weekend catch-up pattern',
            description:
                'You sleep ${SleepStatsService.formatHours(diff)} more on weekends. This "social jet lag" can disrupt your rhythm.',
          ),
        );
      } else if (diff < -0.75) {
        insights.add(
          SleepInsight(
            icon: Icons.weekend,
            color: Colors.orange,
            title: 'Less sleep on weekends',
            description:
                'You sleep ${SleepStatsService.formatHours(-diff)} less on weekends compared to weekdays.',
          ),
        );
      }
    }
  }

  /// Build a stats summary string for use with LLM API.
  static String buildStatsSummary({
    required Map<DateTime, List<SleepRecord>> sleepData,
    required List<CoffeeRecord> coffeeRecords,
    required List<AlcoholRecord> alcoholRecords,
    required List<MedicineRecord> medicineRecords,
  }) {
    final stats7 = SleepStatsService.dailyStats(sleepData, 7);
    final stats30 = SleepStatsService.dailyStats(sleepData, 30);
    final avg7 = SleepStatsService.averageDuration(stats7);
    final avg30 = SleepStatsService.averageDuration(stats30);
    final consistency = SleepStatsService.consistencyScore(stats7);
    final avgBedtime = SleepStatsService.averageBedtime(stats7);
    final avgWake = SleepStatsService.averageWakeTime(stats7);
    final (thisWeek, lastWeek) = SleepStatsService.weeklyComparison(sleepData);
    final best = SleepStatsService.bestNight(stats30);
    final worst = SleepStatsService.worstNight(stats30);

    final coffeeCount = SleepStatsService.countActivitiesInRange(
      coffeeRecords,
      (r) => r.startDate,
      7,
    );
    final alcoholCount = SleepStatsService.countActivitiesInRange(
      alcoholRecords,
      (r) => r.startDate,
      7,
    );
    final medicineCount = SleepStatsService.countActivitiesInRange(
      medicineRecords,
      (r) => r.startDate,
      7,
    );

    final buf = StringBuffer();
    buf.writeln('Sleep diary stats:');
    buf.writeln('- 7-day avg sleep: ${SleepStatsService.formatHours(avg7)}');
    buf.writeln('- 30-day avg sleep: ${SleepStatsService.formatHours(avg30)}');
    buf.writeln('- Consistency score: ${consistency.toInt()}%');
    if (avgBedtime != null) {
      buf.writeln('- Avg bedtime: ${SleepStatsService.formatTime(avgBedtime)}');
    }
    if (avgWake != null) {
      buf.writeln('- Avg wake time: ${SleepStatsService.formatTime(avgWake)}');
    }
    buf.writeln('- This week avg: ${SleepStatsService.formatHours(thisWeek)}');
    buf.writeln('- Last week avg: ${SleepStatsService.formatHours(lastWeek)}');
    if (best != null) {
      buf.writeln(
        '- Best night (30d): ${SleepStatsService.formatHours(best.totalHours)} on ${best.date.toString().split(' ')[0]}',
      );
    }
    if (worst != null) {
      buf.writeln(
        '- Worst night (30d): ${SleepStatsService.formatHours(worst.totalHours)} on ${worst.date.toString().split(' ')[0]}',
      );
    }
    buf.writeln('- Coffee/tea entries (7d): $coffeeCount');
    buf.writeln('- Alcohol entries (7d): $alcoholCount');
    buf.writeln('- Medicine entries (7d): $medicineCount');

    // Last 7 days detail
    buf.writeln('\nDaily breakdown (last 7 days):');
    for (final s in stats7) {
      final dayName = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ][s.date.weekday - 1];
      buf.write('  ${s.date.toString().split(' ')[0]} ($dayName): ');
      if (s.totalHours > 0) {
        buf.write('${SleepStatsService.formatHours(s.totalHours)}');
        if (s.bedtime != null)
          buf.write(', bed ${SleepStatsService.formatTime(s.bedtime!)}');
        if (s.wakeTime != null)
          buf.write(', wake ${SleepStatsService.formatTime(s.wakeTime!)}');
      } else {
        buf.write('no data');
      }
      buf.writeln();
    }

    return buf.toString();
  }
}
