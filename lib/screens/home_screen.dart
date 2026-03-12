import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../utils/helpers.dart';
import '../widgets/widgets.dart';
import '../app.dart';

typedef ActivityRecord = ({
  String letter,
  Color color,
  int startMinutes,
  int endMinutes,
  bool hasStart,
  bool hasEnd,
  String label,
  String startDateStr,
  String startTimeStr,
  String endDateStr,
  String endTimeStr,
  String key,
});

class SleepDiaryHome extends StatefulWidget {
  const SleepDiaryHome({super.key});

  @override
  State<SleepDiaryHome> createState() => _SleepDiaryHomeState();
}

class _SleepDiaryHomeState extends State<SleepDiaryHome> {
  final StorageService _storage = StorageService();
  late ExportImportService _exportImport;

  Map<DateTime, List<SleepRecord>> _sleepData = {};
  List<CoffeeRecord> _coffeeRecords = [];
  List<MedicineRecord> _medicineRecords = [];
  List<AlcoholRecord> _alcoholRecords = [];

  bool _showSleep = true;
  bool _showCoffee = true;
  bool _showMedicine = true;
  bool _showAlcohol = true;

  DateTime _selectedDay = DateTime.now();
  int _currentViewIndex = 0;
  late ScrollController _horizontalScrollController;
  int _timelinePageIndex = 0;

  final Map<String, OverlayEntry> _activeTooltipEntries = {};
  String? _selectedTimelineRecordKey;
  String? _selectedActivityKey;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _exportImport = ExportImportService(_storage);
    _loadAllData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await _storage.init();
    setState(() {
      _sleepData = _storage.loadSleepData();
      _coffeeRecords = _storage.loadCoffeeRecords();
      _medicineRecords = _storage.loadMedicineRecords();
      _alcoholRecords = _storage.loadAlcoholRecords();
    });
  }

  void _addSleepRecord(
    DateTime sleepDate,
    TimeOfDay sleepTime,
    DateTime wakeDate,
    TimeOfDay wakeTime,
  ) {
    final record = SleepRecord(
      sleepDate: sleepDate,
      sleepTime: sleepTime,
      wakeDate: wakeDate,
      wakeTime: wakeTime,
    );
    final key = DateTime(sleepDate.year, sleepDate.month, sleepDate.day);
    _sleepData.putIfAbsent(key, () => []);
    _sleepData[key]!.add(record);
    _storage.saveSleepData(_sleepData);
    setState(() {});
  }

  void _deleteSleepRecord(DateTime date, int index) {
    final key = DateTime(date.year, date.month, date.day);
    if (_sleepData[key] != null && index < _sleepData[key]!.length) {
      _sleepData[key]!.removeAt(index);
      if (_sleepData[key]!.isEmpty) {
        _sleepData.remove(key);
      }
      _storage.saveSleepData(_sleepData);
      setState(() {});
    }
  }

  void _editSleepRecord(SleepRecord oldRecord, SleepRecord newRecord) {
    final oldKey = DateTime(
      oldRecord.sleepDate.year,
      oldRecord.sleepDate.month,
      oldRecord.sleepDate.day,
    );
    _sleepData[oldKey]?.remove(oldRecord);
    if (_sleepData[oldKey]?.isEmpty ?? false) _sleepData.remove(oldKey);

    final newKey = DateTime(
      newRecord.sleepDate.year,
      newRecord.sleepDate.month,
      newRecord.sleepDate.day,
    );
    _sleepData.putIfAbsent(newKey, () => []);
    _sleepData[newKey]!.add(newRecord);
    _storage.saveSleepData(_sleepData);
    setState(() {});
  }

  Future<void> _exportData() async {
    await _exportImport.exportData(
      context: context,
      sleepData: _sleepData,
      coffeeRecords: _coffeeRecords,
      medicineRecords: _medicineRecords,
      alcoholRecords: _alcoholRecords,
    );
  }

  Future<void> _importData() async {
    final imported = await _exportImport.importData(context);
    if (imported == null) return;

    setState(() {
      imported.sleepData.forEach((date, importedRecords) {
        final existing = _sleepData[date] ?? [];
        for (final imp in importedRecords) {
          final isDuplicate = existing.any(
            (e) =>
                e.sleepDate == imp.sleepDate &&
                e.sleepTime == imp.sleepTime &&
                e.wakeDate == imp.wakeDate &&
                e.wakeTime == imp.wakeTime,
          );
          if (!isDuplicate) existing.add(imp);
        }
        _sleepData[date] = existing;
      });

      for (final imp in imported.coffeeRecords) {
        final isDuplicate = _coffeeRecords.any(
          (e) =>
              e.startDate == imp.startDate &&
              e.startTime == imp.startTime &&
              e.endDate == imp.endDate &&
              e.endTime == imp.endTime,
        );
        if (!isDuplicate) _coffeeRecords.add(imp);
      }

      for (final imp in imported.medicineRecords) {
        final isDuplicate = _medicineRecords.any(
          (e) =>
              e.startDate == imp.startDate &&
              e.startTime == imp.startTime &&
              e.endDate == imp.endDate &&
              e.endTime == imp.endTime,
        );
        if (!isDuplicate) _medicineRecords.add(imp);
      }

      for (final imp in imported.alcoholRecords) {
        final isDuplicate = _alcoholRecords.any(
          (e) =>
              e.startDate == imp.startDate &&
              e.startTime == imp.startTime &&
              e.endDate == imp.endDate &&
              e.endTime == imp.endTime,
        );
        if (!isDuplicate) _alcoholRecords.add(imp);
      }
    });

    await _storage.saveSleepData(_sleepData);
    await _storage.saveCoffeeRecords(_coffeeRecords);
    await _storage.saveMedicineRecords(_medicineRecords);
    await _storage.saveAlcoholRecords(_alcoholRecords);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data imported successfully!')),
      );
    }
  }

  void _showAddTypeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Add Entry'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                showAddSleepDialog(
                  context: context,
                  selectedDay: _selectedDay,
                  onSave: _addSleepRecord,
                );
              },
              child: const Text('Sleep Record'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                showAddActivityDialog(
                  context: context,
                  title: 'Coffee/Cola/Tea',
                  selectedDay: _selectedDay,
                  onSave: (s, st, e, et) {
                    _coffeeRecords.add(CoffeeRecord(
                      startDate: s, startTime: st, endDate: e, endTime: et,
                    ));
                    _storage.saveCoffeeRecords(_coffeeRecords);
                    setState(() {});
                  },
                );
              },
              child: const Text('Coffee, Cola, or Tea'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                showAddActivityDialog(
                  context: context,
                  title: 'Medicine',
                  selectedDay: _selectedDay,
                  onSave: (s, st, e, et) {
                    _medicineRecords.add(MedicineRecord(
                      startDate: s, startTime: st, endDate: e, endTime: et,
                    ));
                    _storage.saveMedicineRecords(_medicineRecords);
                    setState(() {});
                  },
                );
              },
              child: const Text('Medicine'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                showAddActivityDialog(
                  context: context,
                  title: 'Alcohol',
                  selectedDay: _selectedDay,
                  onSave: (s, st, e, et) {
                    _alcoholRecords.add(AlcoholRecord(
                      startDate: s, startTime: st, endDate: e, endTime: et,
                    ));
                    _storage.saveAlcoholRecords(_alcoholRecords);
                    setState(() {});
                  },
                );
              },
              child: const Text('Alcohol'),
            ),
          ],
        );
      },
    );
  }

  // --- Segment helpers for timeline ---

  List<SleepBarSegment> _getSegmentsForDate(DateTime date) {
    final List<SleepBarSegment> segments = [];
    final d = DateTime(date.year, date.month, date.day);
    for (final records in _sleepData.values) {
      for (final record in records) {
        final start = DateTime(
          record.sleepDate.year,
          record.sleepDate.month,
          record.sleepDate.day,
        );
        final end = DateTime(
          record.wakeDate.year,
          record.wakeDate.month,
          record.wakeDate.day,
        );
        if (!d.isBefore(start) && !d.isAfter(end)) {
          TimeOfDay segStart, segEnd;
          if (d.isAtSameMomentAs(start) && d.isAtSameMomentAs(end)) {
            segStart = record.sleepTime;
            segEnd = record.wakeTime;
          } else if (d.isAtSameMomentAs(start)) {
            segStart = record.sleepTime;
            segEnd = const TimeOfDay(hour: 23, minute: 59);
          } else if (d.isAtSameMomentAs(end)) {
            segStart = const TimeOfDay(hour: 0, minute: 0);
            segEnd = record.wakeTime;
          } else {
            segStart = const TimeOfDay(hour: 0, minute: 0);
            segEnd = const TimeOfDay(hour: 23, minute: 59);
          }
          segments.add(
            SleepBarSegment(record: record, start: segStart, end: segEnd),
          );
        }
      }
    }
    return segments;
  }

  // --- Activity records for timeline ---

  List<ActivityRecord> _getActivityRecordsForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final List<ActivityRecord> records = [];

    void collect(
      String letter,
      Color color,
      String label,
      DateTime startDate,
      TimeOfDay startTime,
      DateTime endDate,
      TimeOfDay endTime,
    ) {
      final startD = DateTime(startDate.year, startDate.month, startDate.day);
      final endD = DateTime(endDate.year, endDate.month, endDate.day);
      if (d.isBefore(startD) || d.isAfter(endD)) return;

      String fmtTime(TimeOfDay t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

      records.add((
        letter: letter,
        color: color,
        startMinutes: startTime.hour * 60 + startTime.minute,
        endMinutes: endTime.hour * 60 + endTime.minute,
        hasStart: d.isAtSameMomentAs(startD),
        hasEnd: d.isAtSameMomentAs(endD),
        label: label,
        startDateStr: formatDate(startDate),
        startTimeStr: fmtTime(startTime),
        endDateStr: formatDate(endDate),
        endTimeStr: fmtTime(endTime),
        key: '${letter}_${formatDate(startDate)}_${fmtTime(startTime)}_${formatDate(endDate)}_${fmtTime(endTime)}',
      ));
    }

    for (final r in _coffeeRecords) {
      collect('C', Colors.brown, 'Coffee/Cola/Tea', r.startDate, r.startTime, r.endDate, r.endTime);
    }
    for (final r in _alcoholRecords) {
      collect('A', Colors.red, 'Alcohol', r.startDate, r.startTime, r.endDate, r.endTime);
    }
    for (final r in _medicineRecords) {
      collect('M', Colors.green, 'Medicine', r.startDate, r.startTime, r.endDate, r.endTime);
    }

    return records;
  }

  int _getMaxMarkerTrack(DateTime date) {
    final records = _getActivityRecordsForDate(date);
    if (records.isEmpty) return -1;
    return records.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Diary'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') _exportData();
              if (value == 'import') _importData();
              if (value == 'nightMode') MyApp.of(context)?.toggleTheme();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'nightMode',
                child: ListTile(
                  leading: Icon(
                    MyApp.of(context)?.isDarkMode == true
                        ? Icons.light_mode
                        : Icons.dark_mode,
                  ),
                  title: Text(
                    MyApp.of(context)?.isDarkMode == true
                        ? 'Light Mode'
                        : 'Night Mode',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.upload),
                  title: Text('Export Data'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Import Data'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _currentViewIndex == 0
          ? _buildCalendarView()
          : _buildTimelineView(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentViewIndex,
        onTap: (index) {
          setState(() {
            _currentViewIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'Timeline',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTypeDialog(context),
        tooltip: 'Add',
        child: const Icon(Icons.add),
      ),
    );
  }

  // ==================== CALENDAR VIEW ====================

  Widget _buildCalendarView() {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _selectedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
            });
          },
          eventLoader: (day) {
            final List<SleepRecord> result = [];
            for (final records in _sleepData.values) {
              for (final record in records) {
                final start = DateTime(
                  record.sleepDate.year,
                  record.sleepDate.month,
                  record.sleepDate.day,
                );
                final end = DateTime(
                  record.wakeDate.year,
                  record.wakeDate.month,
                  record.wakeDate.day,
                );
                final d = DateTime(day.year, day.month, day.day);
                if (!d.isBefore(start) && !d.isAfter(end)) {
                  result.add(record);
                }
              }
            }
            return result;
          },
          calendarStyle: const CalendarStyle(
            markerDecoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilterChipsWidget(
          showSleep: _showSleep,
          showCoffee: _showCoffee,
          showMedicine: _showMedicine,
          showAlcohol: _showAlcohol,
          onSleepChanged: (val) => setState(() => _showSleep = val),
          onCoffeeChanged: (val) => setState(() => _showCoffee = val),
          onMedicineChanged: (val) => setState(() => _showMedicine = val),
          onAlcoholChanged: (val) => setState(() => _showAlcohol = val),
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildSleepRecordsList()),
      ],
    );
  }

  // ==================== RECORD LIST ====================

  Widget _buildSleepRecordsList() {
    final d = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final List<Widget> recordTiles = [];

    if (_showSleep) {
      final List<SleepRecord> sleepRecords = [];
      _sleepData.values.forEach((recordList) {
        for (final record in recordList) {
          final start = DateTime(
            record.sleepDate.year,
            record.sleepDate.month,
            record.sleepDate.day,
          );
          final end = DateTime(
            record.wakeDate.year,
            record.wakeDate.month,
            record.wakeDate.day,
          );
          if (!d.isBefore(start) && !d.isAfter(end)) {
            sleepRecords.add(record);
          }
        }
      });
      for (final record in sleepRecords) {
        final sleepDateStr = formatDate(record.sleepDate);
        final wakeDateStr = formatDate(record.wakeDate);
        recordTiles.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.indigo[900]
                  : Colors.indigo[50],
              child: ListTile(
                leading: const Icon(Icons.bedtime, color: Colors.indigo),
                title: Text(
                  'Sleep: $sleepDateStr ${record.sleepTime.format(context)} → $wakeDateStr ${record.wakeTime.format(context)}',
                ),
                subtitle: Text(
                  'Duration: ${calculateDuration(record.sleepDate, record.sleepTime, record.wakeDate, record.wakeTime)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => showEditSleepDialog(
                        context: context,
                        record: record,
                        onSave: _editSleepRecord,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        final spansMultipleDays =
                            record.sleepDate.year != record.wakeDate.year ||
                            record.sleepDate.month != record.wakeDate.month ||
                            record.sleepDate.day != record.wakeDate.day;
                        if (spansMultipleDays) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Sleep Record'),
                              content: const Text(
                                'This sleep record spans multiple days. Are you sure you want to delete it?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                        }
                        _deleteSleepRecord(
                          record.sleepDate,
                          _sleepData[DateTime(
                                record.sleepDate.year,
                                record.sleepDate.month,
                                record.sleepDate.day,
                              )]!
                              .indexOf(record),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    if (_showAlcohol) {
      for (final record in _alcoholRecords) {
        final start = DateTime(record.startDate.year, record.startDate.month, record.startDate.day);
        final end = DateTime(record.endDate.year, record.endDate.month, record.endDate.day);
        if (!d.isBefore(start) && !d.isAfter(end)) {
          recordTiles.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.red[900]
                    : Colors.red[50],
                child: ListTile(
                  leading: const Icon(Icons.local_bar, color: Colors.red),
                  title: Text(
                    'Alcohol: ${formatDate(record.startDate)} ${record.startTime.format(context)} → ${formatDate(record.endDate)} ${record.endTime.format(context)}',
                  ),
                  subtitle: Text(
                    'Duration: ${calculateDuration(record.startDate, record.startTime, record.endDate, record.endTime)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => showEditActivityDialog(
                          context: context,
                          title: 'Alcohol',
                          startDateInit: record.startDate,
                          startTimeInit: record.startTime,
                          endDateInit: record.endDate,
                          endTimeInit: record.endTime,
                          onSave: (s, st, e, et) {
                            final idx = _alcoholRecords.indexOf(record);
                            if (idx != -1) {
                              _alcoholRecords[idx] = AlcoholRecord(
                                startDate: s, startTime: st, endDate: e, endTime: et,
                              );
                              _storage.saveAlcoholRecords(_alcoholRecords);
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() => _alcoholRecords.remove(record));
                          _storage.saveAlcoholRecords(_alcoholRecords);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    if (_showCoffee) {
      for (final record in _coffeeRecords) {
        final start = DateTime(record.startDate.year, record.startDate.month, record.startDate.day);
        final end = DateTime(record.endDate.year, record.endDate.month, record.endDate.day);
        if (!d.isBefore(start) && !d.isAfter(end)) {
          recordTiles.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.brown[900]
                    : Colors.brown[50],
                child: ListTile(
                  leading: const Icon(Icons.coffee, color: Colors.brown),
                  title: Text(
                    'Coffee/Cola/Tea: ${formatDate(record.startDate)} ${record.startTime.format(context)} → ${formatDate(record.endDate)} ${record.endTime.format(context)}',
                  ),
                  subtitle: Text(
                    'Duration: ${calculateDuration(record.startDate, record.startTime, record.endDate, record.endTime)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => showEditActivityDialog(
                          context: context,
                          title: 'Coffee/Cola/Tea',
                          startDateInit: record.startDate,
                          startTimeInit: record.startTime,
                          endDateInit: record.endDate,
                          endTimeInit: record.endTime,
                          onSave: (s, st, e, et) {
                            final idx = _coffeeRecords.indexOf(record);
                            if (idx != -1) {
                              _coffeeRecords[idx] = CoffeeRecord(
                                startDate: s, startTime: st, endDate: e, endTime: et,
                              );
                              _storage.saveCoffeeRecords(_coffeeRecords);
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() => _coffeeRecords.remove(record));
                          _storage.saveCoffeeRecords(_coffeeRecords);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    if (_showMedicine) {
      for (final record in _medicineRecords) {
        final start = DateTime(record.startDate.year, record.startDate.month, record.startDate.day);
        final end = DateTime(record.endDate.year, record.endDate.month, record.endDate.day);
        if (!d.isBefore(start) && !d.isAfter(end)) {
          recordTiles.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.green[900]
                    : Colors.green[50],
                child: ListTile(
                  leading: const Icon(Icons.medication, color: Colors.green),
                  title: Text(
                    'Medicine: ${formatDate(record.startDate)} ${record.startTime.format(context)} → ${formatDate(record.endDate)} ${record.endTime.format(context)}',
                  ),
                  subtitle: Text(
                    'Duration: ${calculateDuration(record.startDate, record.startTime, record.endDate, record.endTime)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => showEditActivityDialog(
                          context: context,
                          title: 'Medicine',
                          startDateInit: record.startDate,
                          startTimeInit: record.startTime,
                          endDateInit: record.endDate,
                          endTimeInit: record.endTime,
                          onSave: (s, st, e, et) {
                            final idx = _medicineRecords.indexOf(record);
                            if (idx != -1) {
                              _medicineRecords[idx] = MedicineRecord(
                                startDate: s, startTime: st, endDate: e, endTime: et,
                              );
                              _storage.saveMedicineRecords(_medicineRecords);
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() => _medicineRecords.remove(record));
                          _storage.saveMedicineRecords(_medicineRecords);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    if (recordTiles.isEmpty) {
      return const Center(child: Text('No records for this day'));
    }

    return ListView(children: recordTiles);
  }

  // ==================== TIMELINE VIEW ====================

  Widget _buildTimelineView() {
    final Set<DateTime> allDatesSet = {};
    for (final records in _sleepData.values) {
      for (final record in records) {
        DateTime d = DateTime(
          record.sleepDate.year,
          record.sleepDate.month,
          record.sleepDate.day,
        );
        final end = DateTime(
          record.wakeDate.year,
          record.wakeDate.month,
          record.wakeDate.day,
        );
        while (!d.isAfter(end)) {
          allDatesSet.add(d);
          d = d.add(const Duration(days: 1));
        }
      }
    }
    final allDates = allDatesSet.toList()..sort((a, b) => a.compareTo(b));

    if (allDates.isEmpty) {
      return const Center(child: Text('No sleep records yet'));
    }

    const int itemsPerPage = 7;
    final totalPages = (allDates.length / itemsPerPage).ceil();

    if (_timelinePageIndex >= totalPages) {
      _timelinePageIndex = totalPages - 1;
    }

    final startIndex = _timelinePageIndex * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, allDates.length);
    final pageDates = allDates.sublist(startIndex, endIndex);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _timelinePageIndex > 0
                    ? () => setState(() => _timelinePageIndex--)
                    : null,
              ),
              Text(
                'Page ${_timelinePageIndex + 1} of $totalPages',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _timelinePageIndex < totalPages - 1
                    ? () => setState(() => _timelinePageIndex++)
                    : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              child: Column(
                children: [
                  _buildTimelineHeader(),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: pageDates
                        .map((date) => _buildTimelineRow(
                              date,
                              _getSegmentsForDate(date),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getDisplayHourLabel(int hourIndex) {
    if (hourIndex == 0) return '12AM';
    if (hourIndex < 12) return '${hourIndex}AM';
    if (hourIndex == 12) return '12PM';
    return '${hourIndex - 12}PM';
  }

  Widget _buildTimelineHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? Colors.grey[900] : Colors.grey[200];
    final hourLabelColor = isDark ? Colors.white70 : Colors.grey[800];
    final dateLabelColor = isDark ? Colors.white : Colors.black87;
    return Container(
      color: headerBg,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              'Date',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: dateLabelColor,
              ),
            ),
          ),
          Row(
            children: List.generate(24, (hourIndex) {
              return SizedBox(
                width: 40,
                height: 60,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      _getDisplayHourLabel(hourIndex),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: hourLabelColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(DateTime date, List<SleepBarSegment> segments) {
    final tracks = <int, int>{};
    final segs = _getSegmentsForDate(date);

    String recordKey(SleepRecord r) =>
        '${r.sleepDate.toIso8601String()}_${r.sleepTime.hour}:${r.sleepTime.minute}_${r.wakeDate.toIso8601String()}_${r.wakeTime.hour}:${r.wakeTime.minute}';

    String? selectedRecordKey = _selectedTimelineRecordKey;
    final List<GlobalKey> barKeys = List.generate(segs.length, (_) => GlobalKey());

    for (int i = 0; i < segs.length; i++) {
      int assignedTrack = 0;
      final segI = segs[i];
      final segIStart = segI.start.hour * 60 + segI.start.minute;
      final segIEnd = segI.end.hour * 60 + segI.end.minute;
      for (int j = 0; j < i; j++) {
        final segJ = segs[j];
        final segJStart = segJ.start.hour * 60 + segJ.start.minute;
        final segJEnd = segJ.end.hour * 60 + segJ.end.minute;
        if (!(segIEnd <= segJStart || segIStart >= segJEnd)) {
          assignedTrack = tracks[j]! + 1;
        }
      }
      tracks[i] = assignedTrack;
    }

    final maxTrack = tracks.isEmpty ? 0 : tracks.values.reduce((a, b) => a > b ? a : b);
    final maxMarkerTrack = _getMaxMarkerTrack(date);
    final hasMarkers = maxMarkerTrack >= 0;
    final markerHeight = hasMarkers ? (maxMarkerTrack + 1) * 22.0 : 0.0;
    final sleepHeight = (maxTrack + 1) * 25.0 + 16;
    final rowHeight = sleepHeight + markerHeight + (hasMarkers ? 4 : 0);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: gridColor)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date.toString().split(' ')[0],
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(getDayName(date), style: const TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 24 * 40 + 1,
            height: rowHeight,
            child: Stack(
              children: [
                Row(
                  children: [
                    Container(width: 1, color: gridColor),
                    ...List.generate(24, (hourIndex) {
                      return Container(
                        width: 40,
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: gridColor, width: 1),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                ...segs.asMap().entries.map((entry) {
                  final seg = entry.value;
                  final segIndex = entry.key;
                  final track = tracks[segIndex] ?? 0;
                  final sleepDateStr = formatDate(seg.record.sleepDate);
                  final wakeDateStr = formatDate(seg.record.wakeDate);
                  final sleepTimeStr = seg.record.sleepTime.format(context);
                  final wakeTimeStr = seg.record.wakeTime.format(context);
                  final durationStr = calculateDuration(
                    seg.record.sleepDate,
                    seg.record.sleepTime,
                    seg.record.wakeDate,
                    seg.record.wakeTime,
                  );
                  final tooltipText =
                      'Sleep: $sleepDateStr $sleepTimeStr\nWake: $wakeDateStr $wakeTimeStr\nDuration: $durationStr';
                  final barKey = barKeys[segIndex];
                  final tooltipKey = '${date.toIso8601String()}-$segIndex';
                  final thisRecordKey = recordKey(seg.record);

                  void showTooltip() {
                    _activeTooltipEntries[tooltipKey]?.remove();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final overlay = Overlay.of(context, rootOverlay: true);
                      final RenderBox? box =
                          barKey.currentContext?.findRenderObject() as RenderBox?;
                      OverlayEntry? overlayEntry;
                      if (box != null && box.attached) {
                        final pos = box.localToGlobal(Offset.zero);
                        overlayEntry = OverlayEntry(
                          builder: (context) => Positioned(
                            left: pos.dx,
                            top: pos.dy - 48,
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tooltipText,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        overlayEntry = OverlayEntry(
                          builder: (context) => Center(
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tooltipText,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      overlay.insert(overlayEntry);
                      _activeTooltipEntries[tooltipKey] = overlayEntry;
                    });
                  }

                  void hideTooltip() {
                    _activeTooltipEntries[tooltipKey]?.remove();
                    _activeTooltipEntries.remove(tooltipKey);
                  }

                  return Positioned(
                    top: 8.0 + track * 25.0,
                    height: 20,
                    left: (seg.start.hour * 60 + seg.start.minute) /
                        (24 * 60) *
                        (24 * 40),
                    width: ((seg.end.hour * 60 + seg.end.minute) -
                            (seg.start.hour * 60 + seg.start.minute)) /
                        (24 * 60) *
                        (24 * 40),
                    child: GestureDetector(
                      onLongPress: () {
                        setState(() => _selectedTimelineRecordKey = thisRecordKey);
                        showTooltip();
                      },
                      onLongPressUp: () {
                        setState(() => _selectedTimelineRecordKey = null);
                        hideTooltip();
                      },
                      onLongPressCancel: () {
                        setState(() => _selectedTimelineRecordKey = null);
                        hideTooltip();
                      },
                      child: AnimatedContainer(
                        key: barKey,
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: (selectedRecordKey != null &&
                                  selectedRecordKey == thisRecordKey)
                              ? Colors.orange
                              : Colors.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  );
                }),
                ..._buildActivityMarkers(date, rowHeight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ACTIVITY MARKERS ====================

  List<Widget> _buildActivityMarkers(DateTime date, double rowHeight) {
    final List<Widget> markers = [];
    const totalWidth = 24 * 40.0;
    const totalMinutes = 24 * 60;
    const markerSize = 20.0;

    final records = _getActivityRecordsForDate(date);

    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      final track = i;
      final bottomOffset = track * (markerSize + 2);
      final isSelected = _selectedActivityKey == r.key;

      final tooltipText =
          '${r.label}: ${r.startDateStr} ${r.startTimeStr}\n→ ${r.endDateStr} ${r.endTimeStr}';
      final tooltipKey = 'activity_${date.toIso8601String()}_$i';
      final markerKey = GlobalKey();

      void showActivityTooltip() {
        _activeTooltipEntries[tooltipKey]?.remove();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final overlay = Overlay.of(context, rootOverlay: true);
          final RenderBox? box =
              markerKey.currentContext?.findRenderObject() as RenderBox?;
          OverlayEntry? entry;
          if (box != null && box.attached) {
            final pos = box.localToGlobal(Offset.zero);
            entry = OverlayEntry(
              builder: (context) => Positioned(
                left: pos.dx,
                top: pos.dy - 48,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tooltipText,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
            );
          } else {
            entry = OverlayEntry(
              builder: (context) => Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tooltipText,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
            );
          }
          overlay.insert(entry);
          _activeTooltipEntries[tooltipKey] = entry;
        });
      }

      void hideActivityTooltip() {
        _activeTooltipEntries[tooltipKey]?.remove();
        _activeTooltipEntries.remove(tooltipKey);
      }

      // Connecting line
      {
        double lineLeft;
        double lineRight;
        if (r.hasStart && r.hasEnd) {
          lineLeft = r.startMinutes / totalMinutes * totalWidth;
          lineRight = r.endMinutes / totalMinutes * totalWidth;
        } else if (r.hasStart && !r.hasEnd) {
          lineLeft = r.startMinutes / totalMinutes * totalWidth;
          lineRight = totalWidth;
        } else if (!r.hasStart && r.hasEnd) {
          lineLeft = 0;
          lineRight = r.endMinutes / totalMinutes * totalWidth;
        } else {
          lineLeft = 0;
          lineRight = totalWidth;
        }
        if (lineRight - lineLeft > 0) {
          markers.add(
            Positioned(
              left: lineLeft,
              bottom: bottomOffset + markerSize / 2 - 1.5,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: lineRight - lineLeft,
                height: isSelected ? 5 : 3,
                decoration: BoxDecoration(
                  color: isSelected
                      ? r.color.withValues(alpha: 0.6)
                      : r.color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2.5),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: r.color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          );
        }
      }

      Widget buildMarkerCircle(GlobalKey? key) {
        return AnimatedContainer(
          key: key,
          duration: const Duration(milliseconds: 150),
          width: markerSize,
          height: markerSize,
          decoration: BoxDecoration(
            color: isSelected ? r.color.withValues(alpha: 0.85) : r.color,
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: r.color.withValues(alpha: 0.7),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            r.letter,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }

      if (r.hasStart) {
        markers.add(
          Positioned(
            left: r.startMinutes / totalMinutes * totalWidth - markerSize / 2,
            bottom: bottomOffset,
            child: GestureDetector(
              onLongPress: () {
                setState(() => _selectedActivityKey = r.key);
                showActivityTooltip();
              },
              onLongPressUp: () {
                setState(() => _selectedActivityKey = null);
                hideActivityTooltip();
              },
              onLongPressCancel: () {
                setState(() => _selectedActivityKey = null);
                hideActivityTooltip();
              },
              child: buildMarkerCircle(markerKey),
            ),
          ),
        );
      }
      if (r.hasEnd) {
        markers.add(
          Positioned(
            left: r.endMinutes / totalMinutes * totalWidth - markerSize / 2,
            bottom: bottomOffset,
            child: GestureDetector(
              onLongPress: () {
                setState(() => _selectedActivityKey = r.key);
                showActivityTooltip();
              },
              onLongPressUp: () {
                setState(() => _selectedActivityKey = null);
                hideActivityTooltip();
              },
              onLongPressCancel: () {
                setState(() => _selectedActivityKey = null);
                hideActivityTooltip();
              },
              child: buildMarkerCircle(r.hasStart ? null : markerKey),
            ),
          ),
        );
      }
    }

    return markers;
  }
}
