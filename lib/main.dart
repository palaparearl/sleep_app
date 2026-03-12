import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

// Models for other record types
class CoffeeRecord {
  final DateTime startDate;
  final TimeOfDay startTime;
  final DateTime endDate;
  final TimeOfDay endTime;
  CoffeeRecord({
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
  factory CoffeeRecord.fromJson(Map<String, dynamic> json) {
    final startParts = (json['startTime'] as String).split(':');
    final endParts = (json['endTime'] as String).split(':');
    return CoffeeRecord(
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

class AlcoholRecord {
  final DateTime startDate;
  final TimeOfDay startTime;
  final DateTime endDate;
  final TimeOfDay endTime;
  AlcoholRecord({
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
  factory AlcoholRecord.fromJson(Map<String, dynamic> json) {
    final startParts = (json['startTime'] as String).split(':');
    final endParts = (json['endTime'] as String).split(':');
    return AlcoholRecord(
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

// Helper class for timeline bar segments
class _SleepBarSegment {
  final SleepRecord record;
  final TimeOfDay start;
  final TimeOfDay end;
  _SleepBarSegment({
    required this.record,
    required this.start,
    required this.end,
  });
}

void main() {
  runApp(const MyApp());
}

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

  // For backward compatibility
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('nightMode') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
    await prefs.setBool('nightMode', _themeMode == ThemeMode.dark);
  }

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sleep Diary',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C6BC0),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF16213E)),
        cardColor: const Color(0xFF1F2940),
        dialogBackgroundColor: const Color(0xFF1F2940),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF16213E),
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: const SleepDiaryHome(),
    );
  }
}

class SleepDiaryHome extends StatefulWidget {
  const SleepDiaryHome({super.key});

  @override
  State<SleepDiaryHome> createState() => _SleepDiaryHomeState();
}

class _SleepDiaryHomeState extends State<SleepDiaryHome> {
  List<CoffeeRecord> _coffeeRecords = [];
  List<MedicineRecord> _medicineRecords = [];
  List<AlcoholRecord> _alcoholRecords = [];

  // Filter toggles
  bool _showSleep = true;
  bool _showCoffee = true;
  bool _showMedicine = true;
  bool _showAlcohol = true;

  Future<void> _saveCoffeeRecords() async {
    await _prefs.setString(
      'coffeeRecords',
      jsonEncode(_coffeeRecords.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> _saveMedicineRecords() async {
    await _prefs.setString(
      'medicineRecords',
      jsonEncode(_medicineRecords.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> _saveAlcoholRecords() async {
    await _prefs.setString(
      'alcoholRecords',
      jsonEncode(_alcoholRecords.map((r) => r.toJson()).toList()),
    );
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
                _showAddSleepDialog(context);
              },
              child: const Text('Sleep Record'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _showAddCoffeeDialog(context);
              },
              child: const Text('Coffee, Cola, or Tea'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _showAddMedicineDialog(context);
              },
              child: const Text('Medicine'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _showAddAlcoholDialog(context);
              },
              child: const Text('Alcohol'),
            ),
          ],
        );
      },
    );
  }

  void _showAddCoffeeDialog(BuildContext context) {
    DateTime? startDate = _selectedDay;
    TimeOfDay? startTime;
    DateTime? endDate = _selectedDay;
    TimeOfDay? endTime;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Coffee/Cola/Tea'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(
                        startDate != null
                            ? '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}'
                            : 'Select date',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? _selectedDay,
                          firstDate: DateTime.utc(2020, 1, 1),
                          lastDate: DateTime.utc(2030, 12, 31),
                        );
                        if (date != null) setState(() => startDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('Start Time'),
                      subtitle: Text(
                        startTime?.format(context) ?? 'Select time',
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime:
                              startTime ?? const TimeOfDay(hour: 8, minute: 0),
                        );
                        if (time != null) setState(() => startTime = time);
                      },
                    ),
                    ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(
                        endDate != null
                            ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
                            : 'Select date',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? _selectedDay,
                          firstDate: DateTime.utc(2020, 1, 1),
                          lastDate: DateTime.utc(2030, 12, 31),
                        );
                        if (date != null) setState(() => endDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('End Time'),
                      subtitle: Text(endTime?.format(context) ?? 'Select time'),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime:
                              endTime ?? const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (time != null) setState(() => endTime = time);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (startDate != null &&
                        startTime != null &&
                        endDate != null &&
                        endTime != null) {
                      _coffeeRecords.add(
                        CoffeeRecord(
                          startDate: startDate!,
                          startTime: startTime!,
                          endDate: endDate!,
                          endTime: endTime!,
                        ),
                      );
                      _saveCoffeeRecords();
                      Navigator.pop(context);
                      this.setState(() {});
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddMedicineDialog(BuildContext context) {
    DateTime? startDate = _selectedDay;
    TimeOfDay? startTime;
    DateTime? endDate = _selectedDay;
    TimeOfDay? endTime;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Medicine'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(
                        startDate != null
                            ? '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}'
                            : 'Select date',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? _selectedDay,
                          firstDate: DateTime.utc(2020, 1, 1),
                          lastDate: DateTime.utc(2030, 12, 31),
                        );
                        if (date != null) setState(() => startDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('Start Time'),
                      subtitle: Text(
                        startTime?.format(context) ?? 'Select time',
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime:
                              startTime ?? const TimeOfDay(hour: 8, minute: 0),
                        );
                        if (time != null) setState(() => startTime = time);
                      },
                    ),
                    ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(
                        endDate != null
                            ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
                            : 'Select date',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? _selectedDay,
                          firstDate: DateTime.utc(2020, 1, 1),
                          lastDate: DateTime.utc(2030, 12, 31),
                        );
                        if (date != null) setState(() => endDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('End Time'),
                      subtitle: Text(endTime?.format(context) ?? 'Select time'),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime:
                              endTime ?? const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (time != null) setState(() => endTime = time);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (startDate != null &&
                        startTime != null &&
                        endDate != null &&
                        endTime != null) {
                      _medicineRecords.add(
                        MedicineRecord(
                          startDate: startDate!,
                          startTime: startTime!,
                          endDate: endDate!,
                          endTime: endTime!,
                        ),
                      );
                      _saveMedicineRecords();
                      Navigator.pop(context);
                      this.setState(() {});
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddAlcoholDialog(BuildContext context) {
    DateTime? startDate = _selectedDay;
    TimeOfDay? startTime;
    DateTime? endDate = _selectedDay;
    TimeOfDay? endTime;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Alcohol'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(
                        startDate != null
                            ? '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}'
                            : 'Select date',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? _selectedDay,
                          firstDate: DateTime.utc(2020, 1, 1),
                          lastDate: DateTime.utc(2030, 12, 31),
                        );
                        if (date != null) setState(() => startDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('Start Time'),
                      subtitle: Text(
                        startTime?.format(context) ?? 'Select time',
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime:
                              startTime ?? const TimeOfDay(hour: 8, minute: 0),
                        );
                        if (time != null) setState(() => startTime = time);
                      },
                    ),
                    ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(
                        endDate != null
                            ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
                            : 'Select date',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? _selectedDay,
                          firstDate: DateTime.utc(2020, 1, 1),
                          lastDate: DateTime.utc(2030, 12, 31),
                        );
                        if (date != null) setState(() => endDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('End Time'),
                      subtitle: Text(endTime?.format(context) ?? 'Select time'),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime:
                              endTime ?? const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (time != null) setState(() => endTime = time);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (startDate != null &&
                        startTime != null &&
                        endDate != null &&
                        endTime != null) {
                      _alcoholRecords.add(
                        AlcoholRecord(
                          startDate: startDate!,
                          startTime: startTime!,
                          endDate: endDate!,
                          endTime: endTime!,
                        ),
                      );
                      _saveAlcoholRecords();
                      Navigator.pop(context);
                      this.setState(() {});
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Edit dialog methods
  void _showEditCoffeeDialog(BuildContext context, CoffeeRecord record) {
    DateTime? startDate = record.startDate;
    TimeOfDay? startTime = record.startTime;
    DateTime? endDate = record.endDate;
    TimeOfDay? endTime = record.endTime;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Coffee/Cola/Tea'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(
                        '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate!,
                          firstDate: DateTime.utc(2020, 1, 1),
                          lastDate: DateTime.utc(2030, 12, 31),
                        );
                        if (date != null) setState(() => startDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('Start Time'),
                      subtitle: Text(startTime!.format(context)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: startTime!,
                        );
                        if (time != null) setState(() => startTime = time);
                      },
                    ),
                    ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(
                        '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate!,
                          firstDate: DateTime.utc(2020, 1, 1),
                          lastDate: DateTime.utc(2030, 12, 31),
                        );
                        if (date != null) setState(() => endDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('End Time'),
                      subtitle: Text(endTime!.format(context)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: endTime!,
                        );
                        if (time != null) setState(() => endTime = time);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final idx = _coffeeRecords.indexOf(record);
                    if (idx != -1) {
                      _coffeeRecords[idx] = CoffeeRecord(
                        startDate: startDate!,
                        startTime: startTime!,
                        endDate: endDate!,
                        endTime: endTime!,
                      );
                      _saveCoffeeRecords();
                      Navigator.pop(context);
                      this.setState(() {});
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditMedicineDialog(BuildContext context, MedicineRecord record) {
    DateTime? startDate = record.startDate;
    TimeOfDay? startTime = record.startTime;
    DateTime? endDate = record.endDate;
    TimeOfDay? endTime = record.endTime;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Medicine'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(
                        '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate!,
                          firstDate: DateTime.utc(2020, 1, 1),
                          lastDate: DateTime.utc(2030, 12, 31),
                        );
                        if (date != null) setState(() => startDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('Start Time'),
                      subtitle: Text(startTime!.format(context)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: startTime!,
                        );
                        if (time != null) setState(() => startTime = time);
                      },
                    ),
                    ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(
                        '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate!,
                          firstDate: DateTime.utc(2020, 1, 1),
                          lastDate: DateTime.utc(2030, 12, 31),
                        );
                        if (date != null) setState(() => endDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('End Time'),
                      subtitle: Text(endTime!.format(context)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: endTime!,
                        );
                        if (time != null) setState(() => endTime = time);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final idx = _medicineRecords.indexOf(record);
                    if (idx != -1) {
                      _medicineRecords[idx] = MedicineRecord(
                        startDate: startDate!,
                        startTime: startTime!,
                        endDate: endDate!,
                        endTime: endTime!,
                      );
                      _saveMedicineRecords();
                      Navigator.pop(context);
                      this.setState(() {});
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditAlcoholDialog(BuildContext context, AlcoholRecord record) {
    DateTime? startDate = record.startDate;
    TimeOfDay? startTime = record.startTime;
    DateTime? endDate = record.endDate;
    TimeOfDay? endTime = record.endTime;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Alcohol'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(
                        '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate!,
                          firstDate: DateTime.utc(2020, 1, 1),
                          lastDate: DateTime.utc(2030, 12, 31),
                        );
                        if (date != null) setState(() => startDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('Start Time'),
                      subtitle: Text(startTime!.format(context)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: startTime!,
                        );
                        if (time != null) setState(() => startTime = time);
                      },
                    ),
                    ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(
                        '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate!,
                          firstDate: DateTime.utc(2020, 1, 1),
                          lastDate: DateTime.utc(2030, 12, 31),
                        );
                        if (date != null) setState(() => endDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('End Time'),
                      subtitle: Text(endTime!.format(context)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: endTime!,
                        );
                        if (time != null) setState(() => endTime = time);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final idx = _alcoholRecords.indexOf(record);
                    if (idx != -1) {
                      _alcoholRecords[idx] = AlcoholRecord(
                        startDate: startDate!,
                        startTime: startTime!,
                        endDate: endDate!,
                        endTime: endTime!,
                      );
                      _saveAlcoholRecords();
                      Navigator.pop(context);
                      this.setState(() {});
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditSleepDialog(BuildContext context, SleepRecord record) {
    DateTime? sleepDate = record.sleepDate;
    TimeOfDay? sleepTime = record.sleepTime;
    DateTime? wakeDate = record.wakeDate;
    TimeOfDay? wakeTime = record.wakeTime;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Sleep Record'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Sleep Date'),
                      subtitle: Text(
                        '${sleepDate!.year}-${sleepDate!.month.toString().padLeft(2, '0')}-${sleepDate!.day.toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: sleepDate!,
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (date != null) setState(() => sleepDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('Sleep Time'),
                      subtitle: Text(sleepTime!.format(context)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: sleepTime!,
                        );
                        if (time != null) setState(() => sleepTime = time);
                      },
                    ),
                    ListTile(
                      title: const Text('Wake Date'),
                      subtitle: Text(
                        '${wakeDate!.year}-${wakeDate!.month.toString().padLeft(2, '0')}-${wakeDate!.day.toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: wakeDate!,
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (date != null) setState(() => wakeDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('Wake Time'),
                      subtitle: Text(wakeTime!.format(context)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: wakeTime!,
                        );
                        if (time != null) setState(() => wakeTime = time);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final sleepDateTime = DateTime(
                      sleepDate!.year,
                      sleepDate!.month,
                      sleepDate!.day,
                      sleepTime!.hour,
                      sleepTime!.minute,
                    );
                    final wakeDateTime = DateTime(
                      wakeDate!.year,
                      wakeDate!.month,
                      wakeDate!.day,
                      wakeTime!.hour,
                      wakeTime!.minute,
                    );
                    if (wakeDateTime.isBefore(sleepDateTime)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Wake time must be after sleep time'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    // Remove old record
                    final oldKey = DateTime(
                      record.sleepDate.year,
                      record.sleepDate.month,
                      record.sleepDate.day,
                    );
                    _sleepData[oldKey]?.remove(record);
                    if (_sleepData[oldKey]?.isEmpty ?? false)
                      _sleepData.remove(oldKey);
                    // Add updated record
                    final newRecord = SleepRecord(
                      sleepDate: sleepDate!,
                      sleepTime: sleepTime!,
                      wakeDate: wakeDate!,
                      wakeTime: wakeTime!,
                    );
                    final newKey = DateTime(
                      sleepDate!.year,
                      sleepDate!.month,
                      sleepDate!.day,
                    );
                    _sleepData.putIfAbsent(newKey, () => []);
                    _sleepData[newKey]!.add(newRecord);
                    _saveSleepData();
                    Navigator.pop(context);
                    this.setState(() {});
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Store active tooltip overlay entries for timeline bars
  final Map<String, OverlayEntry> _activeTooltipEntries = {};
  // Track selected sleep record key for timeline highlight
  String? _selectedTimelineRecordKey;
  // Track selected activity marker key for timeline highlight
  String? _selectedActivityKey;
  // Returns all record segments that overlap the given date, split as needed
  List<_SleepBarSegment> _getSegmentsForDate(DateTime date) {
    final List<_SleepBarSegment> segments = [];
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
          // This record overlaps this date
          TimeOfDay segStart, segEnd;
          if (d.isAtSameMomentAs(start) && d.isAtSameMomentAs(end)) {
            // Same day
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
            _SleepBarSegment(record: record, start: segStart, end: segEnd),
          );
        }
      }
    }
    return segments;
  }

  late SharedPreferences _prefs;
  Map<DateTime, List<SleepRecord>> _sleepData = {};
  DateTime _selectedDay = DateTime.now();
  int _currentViewIndex = 0; // 0 = Calendar, 1 = Timeline
  late ScrollController _horizontalScrollController;
  int _timelinePageIndex = 0; // For pagination

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _loadAllData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    _prefs = await SharedPreferences.getInstance();
    // Sleep records
    final sleepData = _prefs.getString('sleepData') ?? '{}';
    final sleepJson = jsonDecode(sleepData) as Map<String, dynamic>;
    final newSleepData = <DateTime, List<SleepRecord>>{};
    sleepJson.forEach((key, value) {
      final date = DateTime.parse(key);
      final records = (value as List)
          .map((r) => SleepRecord.fromJson(r as Map<String, dynamic>))
          .toList();
      newSleepData[date] = records;
    });

    // Alcohol records
    final alcoholData = _prefs.getString('alcoholRecords');
    List<AlcoholRecord> alcoholRecords = [];
    if (alcoholData != null) {
      final alcoholList = jsonDecode(alcoholData) as List;
      alcoholRecords = alcoholList
          .map((r) => AlcoholRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    // Coffee records
    final coffeeData = _prefs.getString('coffeeRecords');
    List<CoffeeRecord> coffeeRecords = [];
    if (coffeeData != null) {
      final coffeeList = jsonDecode(coffeeData) as List;
      coffeeRecords = coffeeList
          .map((r) => CoffeeRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    // Medicine records
    final medicineData = _prefs.getString('medicineRecords');
    List<MedicineRecord> medicineRecords = [];
    if (medicineData != null) {
      final medicineList = jsonDecode(medicineData) as List;
      medicineRecords = medicineList
          .map((r) => MedicineRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    setState(() {
      _sleepData = newSleepData;
      _alcoholRecords = alcoholRecords;
      _coffeeRecords = coffeeRecords;
      _medicineRecords = medicineRecords;
    });
  }

  Future<void> _saveSleepData() async {
    final json = <String, dynamic>{};
    _sleepData.forEach((date, records) {
      json[date.toIso8601String()] = records.map((r) => r.toJson()).toList();
    });
    await _prefs.setString('sleepData', jsonEncode(json));
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
    if (_sleepData[key] == null) {
      _sleepData[key] = [];
    }
    _sleepData[key]!.add(record);

    _saveSleepData();
    setState(() {});
  }

  void _deleteSleepRecord(DateTime date, int index) {
    final key = DateTime(date.year, date.month, date.day);
    if (_sleepData[key] != null && index < _sleepData[key]!.length) {
      _sleepData[key]!.removeAt(index);
      if (_sleepData[key]!.isEmpty) {
        _sleepData.remove(key);
      }
      _saveSleepData();
      setState(() {});
    }
  }

  Future<void> _exportData() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export Data'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'share'),
            child: const ListTile(
              leading: Icon(Icons.share),
              title: Text('Share'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const ListTile(
              leading: Icon(Icons.save),
              title: Text('Save to device'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    final sleepJson = <String, dynamic>{};
    _sleepData.forEach((date, records) {
      sleepJson[date.toIso8601String()] = records
          .map((r) => r.toJson())
          .toList();
    });

    final exportData = {
      'version': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'sleepRecords': sleepJson,
      'coffeeRecords': _coffeeRecords.map((r) => r.toJson()).toList(),
      'medicineRecords': _medicineRecords.map((r) => r.toJson()).toList(),
      'alcoholRecords': _alcoholRecords.map((r) => r.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:\.]'),
      '-',
    );
    final fileName = 'sleep_diary_$timestamp.json';

    if (choice == 'share') {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonString);
      await Share.shareXFiles([XFile(file.path)]);
    } else {
      final bytes = utf8.encode(jsonString);
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Sleep Diary Export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(bytes),
      );
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data exported successfully!')),
        );
      }
    }
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    try {
      final content = await File(filePath).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Parse sleep records
      final sleepJson = data['sleepRecords'] as Map<String, dynamic>? ?? {};
      final newSleepData = <DateTime, List<SleepRecord>>{};
      sleepJson.forEach((key, value) {
        final date = DateTime.parse(key);
        final records = (value as List)
            .map((r) => SleepRecord.fromJson(r as Map<String, dynamic>))
            .toList();
        newSleepData[date] = records;
      });

      // Parse coffee records
      final coffeeList = data['coffeeRecords'] as List? ?? [];
      final newCoffeeRecords = coffeeList
          .map((r) => CoffeeRecord.fromJson(r as Map<String, dynamic>))
          .toList();

      // Parse medicine records
      final medicineList = data['medicineRecords'] as List? ?? [];
      final newMedicineRecords = medicineList
          .map((r) => MedicineRecord.fromJson(r as Map<String, dynamic>))
          .toList();

      // Parse alcohol records
      final alcoholList = data['alcoholRecords'] as List? ?? [];
      final newAlcoholRecords = alcoholList
          .map((r) => AlcoholRecord.fromJson(r as Map<String, dynamic>))
          .toList();

      setState(() {
        // Merge sleep records by date key
        newSleepData.forEach((date, importedRecords) {
          final existing = _sleepData[date] ?? [];
          for (final imported in importedRecords) {
            final isDuplicate = existing.any(
              (e) =>
                  e.sleepDate == imported.sleepDate &&
                  e.sleepTime == imported.sleepTime &&
                  e.wakeDate == imported.wakeDate &&
                  e.wakeTime == imported.wakeTime,
            );
            if (!isDuplicate) {
              existing.add(imported);
            }
          }
          _sleepData[date] = existing;
        });

        // Merge coffee records
        for (final imported in newCoffeeRecords) {
          final isDuplicate = _coffeeRecords.any(
            (e) =>
                e.startDate == imported.startDate &&
                e.startTime == imported.startTime &&
                e.endDate == imported.endDate &&
                e.endTime == imported.endTime,
          );
          if (!isDuplicate) _coffeeRecords.add(imported);
        }

        // Merge medicine records
        for (final imported in newMedicineRecords) {
          final isDuplicate = _medicineRecords.any(
            (e) =>
                e.startDate == imported.startDate &&
                e.startTime == imported.startTime &&
                e.endDate == imported.endDate &&
                e.endTime == imported.endTime,
          );
          if (!isDuplicate) _medicineRecords.add(imported);
        }

        // Merge alcohol records
        for (final imported in newAlcoholRecords) {
          final isDuplicate = _alcoholRecords.any(
            (e) =>
                e.startDate == imported.startDate &&
                e.startTime == imported.startTime &&
                e.endDate == imported.endDate &&
                e.endTime == imported.endTime,
          );
          if (!isDuplicate) _alcoholRecords.add(imported);
        }
      });

      await _saveSleepData();
      await _saveCoffeeRecords();
      await _saveMedicineRecords();
      await _saveAlcoholRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data imported successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: Invalid file format')),
        );
      }
    }
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
        onPressed: () {
          _showAddTypeDialog(context);
        },
        tooltip: 'Add',
        child: const Icon(Icons.add),
      ),
    );
  }

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
            // Show all records that overlap this day
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
          calendarStyle: CalendarStyle(
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
        _buildFilterChips(),
        const SizedBox(height: 4),
        Expanded(child: _buildSleepRecordsList()),
      ],
    );
  }

  Widget _buildTimelineView() {
    // Build a set of all dates spanned by any record
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

    // Ensure page index is within bounds
    if (_timelinePageIndex >= totalPages) {
      _timelinePageIndex = totalPages - 1;
    }

    final startIndex = _timelinePageIndex * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, allDates.length);
    final pageDates = allDates.sublist(startIndex, endIndex);

    return Column(
      children: [
        // Previous/Next buttons
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _timelinePageIndex > 0
                    ? () {
                        setState(() {
                          _timelinePageIndex--;
                        });
                      }
                    : null,
              ),
              Text(
                'Page ${_timelinePageIndex + 1} of $totalPages',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _timelinePageIndex < totalPages - 1
                    ? () {
                        setState(() {
                          _timelinePageIndex++;
                        });
                      }
                    : null,
              ),
            ],
          ),
        ),
        // Timeline content
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
                        .map(
                          (date) => _buildTimelineRow(
                            date,
                            _getSegmentsForDate(date),
                          ),
                        )
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
    // Hour index 0-23 represents 12AM to 11PM
    if (hourIndex == 0) {
      return '12AM';
    } else if (hourIndex < 12) {
      return '${hourIndex}AM';
    } else if (hourIndex == 12) {
      return '12PM';
    } else {
      return '${hourIndex - 12}PM';
    }
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
              final displayHour = _getDisplayHourLabel(hourIndex);
              return SizedBox(
                width: 40,
                height: 60,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      displayHour,
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

  Widget _buildTimelineRow(DateTime date, List<_SleepBarSegment> segments) {
    // Assign segments to tracks based on overlaps
    final tracks = <int, int>{}; // segment index -> track number
    final segments = _getSegmentsForDate(date);
    // Helper to get unique key for a record
    String recordKey(SleepRecord r) =>
        '${r.sleepDate.toIso8601String()}_${r.sleepTime.hour}:${r.sleepTime.minute}_${r.wakeDate.toIso8601String()}_${r.wakeTime.hour}:${r.wakeTime.minute}';
    // Use selected record key for highlight
    String? selectedRecordKey = _selectedTimelineRecordKey;
    // Create a stable list of GlobalKeys for each segment
    final List<GlobalKey> barKeys = List.generate(
      segments.length,
      (_) => GlobalKey(),
    );
    for (int i = 0; i < segments.length; i++) {
      int assignedTrack = 0;
      final segI = segments[i];
      final segIStart = segI.start.hour * 60 + segI.start.minute;
      final segIEnd = segI.end.hour * 60 + segI.end.minute;
      for (int j = 0; j < i; j++) {
        final segJ = segments[j];
        final segJStart = segJ.start.hour * 60 + segJ.start.minute;
        final segJEnd = segJ.end.hour * 60 + segJ.end.minute;
        if (!(segIEnd <= segJStart || segIStart >= segJEnd)) {
          assignedTrack = tracks[j]! + 1;
        }
      }
      tracks[i] = assignedTrack;
    }
    final maxTrack = tracks.isEmpty
        ? 0
        : tracks.values.reduce((a, b) => a > b ? a : b);
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(_getDayName(date), style: const TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 24 * 40 + 1,
            height: rowHeight,
            child: Stack(
              children: [
                // Grid lines for hours
                Row(
                  children: [
                    // Line for 12AM (start of day)
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
                // Sleep bars positioned by track
                ...segments.asMap().entries.map((entry) {
                  final seg = entry.value;
                  final segIndex = entry.key;
                  final track = tracks[segIndex] ?? 0;
                  // Always show full record details in tooltip
                  final sleepDateStr =
                      '${seg.record.sleepDate.year}-${seg.record.sleepDate.month.toString().padLeft(2, '0')}-${seg.record.sleepDate.day.toString().padLeft(2, '0')}';
                  final wakeDateStr =
                      '${seg.record.wakeDate.year}-${seg.record.wakeDate.month.toString().padLeft(2, '0')}-${seg.record.wakeDate.day.toString().padLeft(2, '0')}';
                  final sleepTimeStr = seg.record.sleepTime.format(context);
                  final wakeTimeStr = seg.record.wakeTime.format(context);
                  final durationStr = _calculateDuration(
                    seg.record.sleepDate,
                    seg.record.sleepTime,
                    seg.record.wakeDate,
                    seg.record.wakeTime,
                  );
                  final tooltipText =
                      'Sleep: $sleepDateStr $sleepTimeStr\nWake: $wakeDateStr $wakeTimeStr\nDuration: $durationStr';
                  final barKey = barKeys[segIndex];
                  // Key for this bar's tooltip entry in the map
                  final tooltipKey = '${date.toIso8601String()}-$segIndex';
                  final thisRecordKey = recordKey(seg.record);
                  void showTooltip() {
                    // Remove any existing tooltip for this bar
                    _activeTooltipEntries[tooltipKey]?.remove();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final overlay = Overlay.of(context, rootOverlay: true);
                      final RenderBox? box =
                          barKey.currentContext?.findRenderObject()
                              as RenderBox?;
                      OverlayEntry? entry;
                      if (box != null && box.attached) {
                        final Offset barPosition = box.localToGlobal(
                          Offset.zero,
                        );
                        final Size barSize = box.size;
                        entry = OverlayEntry(
                          builder: (context) => Positioned(
                            left: barPosition.dx,
                            top: barPosition.dy - 48,
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      overlay.insert(entry!);
                      _activeTooltipEntries[tooltipKey] = entry!;
                    });
                  }

                  void hideTooltip() {
                    _activeTooltipEntries[tooltipKey]?.remove();
                    _activeTooltipEntries.remove(tooltipKey);
                  }

                  return Positioned(
                    top: 8.0 + track * 25.0,
                    height: 20,
                    left:
                        (seg.start.hour * 60 + seg.start.minute) /
                        (24 * 60) *
                        (24 * 40),
                    width:
                        ((seg.end.hour * 60 + seg.end.minute) -
                            (seg.start.hour * 60 + seg.start.minute)) /
                        (24 * 60) *
                        (24 * 40),
                    child: GestureDetector(
                      onLongPress: () {
                        setState(() {
                          _selectedTimelineRecordKey = thisRecordKey;
                        });
                        showTooltip();
                      },
                      onLongPressUp: () {
                        setState(() {
                          _selectedTimelineRecordKey = null;
                        });
                        hideTooltip();
                      },
                      onLongPressCancel: () {
                        setState(() {
                          _selectedTimelineRecordKey = null;
                        });
                        hideTooltip();
                      },
                      child: AnimatedContainer(
                        key: barKey,
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color:
                              (selectedRecordKey != null &&
                                  selectedRecordKey == thisRecordKey)
                              ? Colors.orange
                              : Colors.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                // Activity markers for coffee, alcohol, medicine
                ..._buildActivityMarkers(date, rowHeight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Collect activity records relevant to a date, each with a letter, color, start/end info
  List<
    ({
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
    })
  >
  _getActivityRecordsForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final List<
      ({
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
      })
    >
    records = [];

    String fmtDate(DateTime dt) =>
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    String fmtTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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

      records.add((
        letter: letter,
        color: color,
        startMinutes: startTime.hour * 60 + startTime.minute,
        endMinutes: endTime.hour * 60 + endTime.minute,
        hasStart: d.isAtSameMomentAs(startD),
        hasEnd: d.isAtSameMomentAs(endD),
        label: label,
        startDateStr: fmtDate(startDate),
        startTimeStr: fmtTime(startTime),
        endDateStr: fmtDate(endDate),
        endTimeStr: fmtTime(endTime),
        key:
            '${letter}_${fmtDate(startDate)}_${fmtTime(startTime)}_${fmtDate(endDate)}_${fmtTime(endTime)}',
      ));
    }

    for (final r in _coffeeRecords) {
      collect(
        'C',
        Colors.brown,
        'Coffee/Cola/Tea',
        r.startDate,
        r.startTime,
        r.endDate,
        r.endTime,
      );
    }
    for (final r in _alcoholRecords) {
      collect(
        'A',
        Colors.red,
        'Alcohol',
        r.startDate,
        r.startTime,
        r.endDate,
        r.endTime,
      );
    }
    for (final r in _medicineRecords) {
      collect(
        'M',
        Colors.green,
        'Medicine',
        r.startDate,
        r.startTime,
        r.endDate,
        r.endTime,
      );
    }

    return records;
  }

  // Assign each activity record its own track so they never overlap
  List<int> _assignMarkerTracks(
    List<
      ({
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
      })
    >
    records,
  ) {
    return List<int>.generate(records.length, (i) => i);
  }

  int _getMaxMarkerTrack(DateTime date) {
    final records = _getActivityRecordsForDate(date);
    if (records.isEmpty) return -1;
    final tracks = _assignMarkerTracks(records);
    return tracks.reduce((a, b) => a > b ? a : b);
  }

  List<Widget> _buildActivityMarkers(DateTime date, double rowHeight) {
    final List<Widget> markers = [];
    const totalWidth = 24 * 40.0;
    const totalMinutes = 24 * 60;
    const markerSize = 20.0;

    final records = _getActivityRecordsForDate(date);
    final tracks = _assignMarkerTracks(records);

    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      final track = tracks[i];
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
          overlay.insert(entry!);
          _activeTooltipEntries[tooltipKey] = entry!;
        });
      }

      void hideActivityTooltip() {
        _activeTooltipEntries[tooltipKey]?.remove();
        _activeTooltipEntries.remove(tooltipKey);
      }

      // Connecting line
      {
        double? lineLeft;
        double? lineRight;
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
                setState(() {
                  _selectedActivityKey = r.key;
                });
                showActivityTooltip();
              },
              onLongPressUp: () {
                setState(() {
                  _selectedActivityKey = null;
                });
                hideActivityTooltip();
              },
              onLongPressCancel: () {
                setState(() {
                  _selectedActivityKey = null;
                });
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
                setState(() {
                  _selectedActivityKey = r.key;
                });
                showActivityTooltip();
              },
              onLongPressUp: () {
                setState(() {
                  _selectedActivityKey = null;
                });
                hideActivityTooltip();
              },
              onLongPressCancel: () {
                setState(() {
                  _selectedActivityKey = null;
                });
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

  Map<int, int> _assignTracksToRecords(List<SleepRecord> records) {
    final tracks = <int, int>{}; // record index -> track number

    for (int i = 0; i < records.length; i++) {
      int assignedTrack = 0;
      final recordI = records[i];
      final recordIStart =
          recordI.sleepTime.hour * 60 + recordI.sleepTime.minute;
      final recordIEnd = recordI.wakeTime.hour * 60 + recordI.wakeTime.minute;
      final recordIStartAdjusted = recordIEnd < recordIStart
          ? recordIStart
          : recordIStart;
      final recordIEndAdjusted = recordIEnd < recordIStart
          ? recordIEnd + 24 * 60
          : recordIEnd;

      // Check against all previously assigned records
      for (int j = 0; j < i; j++) {
        final recordJ = records[j];
        final recordJStart =
            recordJ.sleepTime.hour * 60 + recordJ.sleepTime.minute;
        final recordJEnd = recordJ.wakeTime.hour * 60 + recordJ.wakeTime.minute;
        final recordJStartAdjusted = recordJEnd < recordJStart
            ? recordJStart
            : recordJStart;
        final recordJEndAdjusted = recordJEnd < recordJStart
            ? recordJEnd + 24 * 60
            : recordJEnd;

        final trackJ = tracks[j] ?? 0;

        // Check if records overlap
        if (_recordsOverlap(
          recordIStartAdjusted,
          recordIEndAdjusted,
          recordJStartAdjusted,
          recordJEndAdjusted,
        )) {
          // If they overlap and j is on the same track, move i to next track
          if (assignedTrack == trackJ) {
            assignedTrack = trackJ + 1;
          }
        }
      }

      tracks[i] = assignedTrack;
    }

    return tracks;
  }

  bool _recordsOverlap(int startA, int endA, int startB, int endB) {
    return !(endA <= startB || endB <= startA);
  }

  Widget _buildSleepBarRow(SleepRecord record) {
    final sleepStartMinutes =
        record.sleepTime.hour * 60 + record.sleepTime.minute;
    final wakeMinutes = record.wakeTime.hour * 60 + record.wakeTime.minute;

    late int startHour;
    late int endHour;
    late int startMinuteInHour;
    late int endMinuteInHour;
    late bool crossesMidnight;

    if (wakeMinutes > sleepStartMinutes) {
      // Sleep on same day
      startHour = record.sleepTime.hour;
      endHour = record.wakeTime.hour;
      startMinuteInHour = record.sleepTime.minute;
      endMinuteInHour = record.wakeTime.minute;
      crossesMidnight = false;
    } else {
      // Sleep crosses midnight
      startHour = record.sleepTime.hour;
      endHour = record.wakeTime.hour + 24; // Virtual hour for next day
      startMinuteInHour = record.sleepTime.minute;
      endMinuteInHour = record.wakeTime.minute;
      crossesMidnight = true;
    }

    return Stack(
      children: [
        // Calculate exact positioning
        ..._buildSleepSegments(
          startHour,
          endHour,
          startMinuteInHour,
          endMinuteInHour,
          crossesMidnight,
        ),
      ],
    );
  }

  List<Widget> _buildSleepSegments(
    int startHour,
    int endHour,
    int startMinute,
    int endMinute,
    bool crossesMidnight,
  ) {
    final segments = <Widget>[];

    if (crossesMidnight) {
      // From sleep time to midnight
      final midnightStartOffset = startMinute / 60;
      segments.add(
        Positioned(
          left: (startHour + midnightStartOffset) * 40,
          right: 0,
          top: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue[300],
              border: Border.all(color: Colors.blue[700]!, width: 0.5),
            ),
          ),
        ),
      );

      // From midnight to wake time
      final wakeOffset = endMinute / 60;
      segments.add(
        Positioned(
          left: 0,
          right: (24 - endHour - wakeOffset) * 40,
          top: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue[300],
              border: Border.all(color: Colors.blue[700]!, width: 0.5),
            ),
          ),
        ),
      );
    } else {
      // Simple case: sleep within same day
      final startOffset = startMinute / 60;
      final endOffset = endMinute / 60;
      segments.add(
        Positioned(
          left: (startHour + startOffset) * 40,
          right: (24 - endHour - endOffset) * 40,
          top: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue[300],
              border: Border.all(color: Colors.blue[700]!, width: 0.5),
            ),
          ),
        ),
      );
    }

    return segments;
  }

  String _getDayName(DateTime date) {
    final days = [
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

  Widget _buildFilterChips() {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: Text(
              'Sleep',
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            avatar: Icon(
              Icons.bedtime,
              size: 18,
              color: isDark ? Colors.indigo[200] : null,
            ),
            selected: _showSleep,
            selectedColor: isDark ? Colors.indigo[700] : Colors.indigo[100],
            checkmarkColor: isDark ? Colors.white : null,
            onSelected: (val) => setState(() => _showSleep = val),
          ),
          FilterChip(
            label: Text(
              'Coffee/Cola/Tea',
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            avatar: Icon(
              Icons.coffee,
              size: 18,
              color: isDark ? Colors.brown[200] : null,
            ),
            selected: _showCoffee,
            selectedColor: isDark ? Colors.brown[700] : Colors.brown[100],
            checkmarkColor: isDark ? Colors.white : null,
            onSelected: (val) => setState(() => _showCoffee = val),
          ),
          FilterChip(
            label: Text(
              'Medicine',
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            avatar: Icon(
              Icons.medication,
              size: 18,
              color: isDark ? Colors.green[200] : null,
            ),
            selected: _showMedicine,
            selectedColor: isDark ? Colors.green[700] : Colors.green[100],
            checkmarkColor: isDark ? Colors.white : null,
            onSelected: (val) => setState(() => _showMedicine = val),
          ),
          FilterChip(
            label: Text(
              'Alcohol',
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            avatar: Icon(
              Icons.local_bar,
              size: 18,
              color: isDark ? Colors.red[200] : null,
            ),
            selected: _showAlcohol,
            selectedColor: isDark ? Colors.red[700] : Colors.red[100],
            checkmarkColor: isDark ? Colors.white : null,
            onSelected: (val) => setState(() => _showAlcohol = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepRecordsList() {
    final d = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final List<Widget> recordTiles = [];

    // Sleep records
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
        final sleepDateStr =
            '${record.sleepDate.year}-${record.sleepDate.month.toString().padLeft(2, '0')}-${record.sleepDate.day.toString().padLeft(2, '0')}';
        final wakeDateStr =
            '${record.wakeDate.year}-${record.wakeDate.month.toString().padLeft(2, '0')}-${record.wakeDate.day.toString().padLeft(2, '0')}';
        recordTiles.add(
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
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
                  'Duration: ${_calculateDuration(record.sleepDate, record.sleepTime, record.wakeDate, record.wakeTime)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditSleepDialog(context, record),
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
                                  onPressed: () =>
                                      Navigator.pop(context, false),
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

    // Alcohol records
    if (_showAlcohol) {
      for (final record in _alcoholRecords) {
        final start = DateTime(
          record.startDate.year,
          record.startDate.month,
          record.startDate.day,
        );
        final end = DateTime(
          record.endDate.year,
          record.endDate.month,
          record.endDate.day,
        );
        if (!d.isBefore(start) && !d.isAfter(end)) {
          final startDateStr =
              '${record.startDate.year}-${record.startDate.month.toString().padLeft(2, '0')}-${record.startDate.day.toString().padLeft(2, '0')}';
          final endDateStr =
              '${record.endDate.year}-${record.endDate.month.toString().padLeft(2, '0')}-${record.endDate.day.toString().padLeft(2, '0')}';
          recordTiles.add(
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.red[900]
                    : Colors.red[50],
                child: ListTile(
                  leading: const Icon(Icons.local_bar, color: Colors.red),
                  title: Text(
                    'Alcohol: $startDateStr ${record.startTime.format(context)} → $endDateStr ${record.endTime.format(context)}',
                  ),
                  subtitle: Text(
                    'Duration: ${_calculateDuration(record.startDate, record.startTime, record.endDate, record.endTime)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showEditAlcoholDialog(context, record),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _alcoholRecords.remove(record);
                          });
                          _saveAlcoholRecords();
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

    // Coffee records
    if (_showCoffee) {
      for (final record in _coffeeRecords) {
        final start = DateTime(
          record.startDate.year,
          record.startDate.month,
          record.startDate.day,
        );
        final end = DateTime(
          record.endDate.year,
          record.endDate.month,
          record.endDate.day,
        );
        if (!d.isBefore(start) && !d.isAfter(end)) {
          final startDateStr =
              '${record.startDate.year}-${record.startDate.month.toString().padLeft(2, '0')}-${record.startDate.day.toString().padLeft(2, '0')}';
          final endDateStr =
              '${record.endDate.year}-${record.endDate.month.toString().padLeft(2, '0')}-${record.endDate.day.toString().padLeft(2, '0')}';
          recordTiles.add(
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.brown[900]
                    : Colors.brown[50],
                child: ListTile(
                  leading: const Icon(Icons.coffee, color: Colors.brown),
                  title: Text(
                    'Coffee/Cola/Tea: $startDateStr ${record.startTime.format(context)} → $endDateStr ${record.endTime.format(context)}',
                  ),
                  subtitle: Text(
                    'Duration: ${_calculateDuration(record.startDate, record.startTime, record.endDate, record.endTime)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditCoffeeDialog(context, record),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _coffeeRecords.remove(record);
                          });
                          _saveCoffeeRecords();
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

    // Medicine records
    if (_showMedicine) {
      for (final record in _medicineRecords) {
        final start = DateTime(
          record.startDate.year,
          record.startDate.month,
          record.startDate.day,
        );
        final end = DateTime(
          record.endDate.year,
          record.endDate.month,
          record.endDate.day,
        );
        if (!d.isBefore(start) && !d.isAfter(end)) {
          final startDateStr =
              '${record.startDate.year}-${record.startDate.month.toString().padLeft(2, '0')}-${record.startDate.day.toString().padLeft(2, '0')}';
          final endDateStr =
              '${record.endDate.year}-${record.endDate.month.toString().padLeft(2, '0')}-${record.endDate.day.toString().padLeft(2, '0')}';
          recordTiles.add(
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.green[900]
                    : Colors.green[50],
                child: ListTile(
                  leading: const Icon(Icons.medication, color: Colors.green),
                  title: Text(
                    'Medicine: $startDateStr ${record.startTime.format(context)} → $endDateStr ${record.endTime.format(context)}',
                  ),
                  subtitle: Text(
                    'Duration: ${_calculateDuration(record.startDate, record.startTime, record.endDate, record.endTime)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showEditMedicineDialog(context, record),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _medicineRecords.remove(record);
                          });
                          _saveMedicineRecords();
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

  String _calculateDuration(
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

  void _showAddSleepDialog(BuildContext context) {
    DateTime? sleepDate = _selectedDay;
    TimeOfDay? sleepTime;
    DateTime? wakeDate = _selectedDay;
    TimeOfDay? wakeTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Sleep Record'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Sleep Date'),
                      subtitle: Text(
                        sleepDate != null
                            ? '${sleepDate!.year}-${sleepDate!.month.toString().padLeft(2, '0')}-${sleepDate!.day.toString().padLeft(2, '0')}'
                            : 'Select date',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: sleepDate ?? DateTime.now(),
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (date != null) setState(() => sleepDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('Sleep Time'),
                      subtitle: Text(
                        sleepTime?.format(context) ?? 'Select time',
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime:
                              sleepTime ?? const TimeOfDay(hour: 22, minute: 0),
                        );
                        if (time != null) setState(() => sleepTime = time);
                      },
                    ),
                    ListTile(
                      title: const Text('Wake Date'),
                      subtitle: Text(
                        wakeDate != null
                            ? '${wakeDate!.year}-${wakeDate!.month.toString().padLeft(2, '0')}-${wakeDate!.day.toString().padLeft(2, '0')}'
                            : 'Select date',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: wakeDate ?? DateTime.now(),
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (date != null) setState(() => wakeDate = date);
                      },
                    ),
                    ListTile(
                      title: const Text('Wake Time'),
                      subtitle: Text(
                        wakeTime?.format(context) ?? 'Select time',
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime:
                              wakeTime ?? const TimeOfDay(hour: 7, minute: 0),
                        );
                        if (time != null) setState(() => wakeTime = time);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (sleepDate != null &&
                        sleepTime != null &&
                        wakeDate != null &&
                        wakeTime != null) {
                      // Create DateTime objects for comparison
                      final sleepDateTime = DateTime(
                        sleepDate!.year,
                        sleepDate!.month,
                        sleepDate!.day,
                        sleepTime!.hour,
                        sleepTime!.minute,
                      );
                      final wakeDateTime = DateTime(
                        wakeDate!.year,
                        wakeDate!.month,
                        wakeDate!.day,
                        wakeTime!.hour,
                        wakeTime!.minute,
                      );

                      // Validate that wake time is after sleep time
                      if (wakeDateTime.isBefore(sleepDateTime)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Wake time must be after sleep time'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      _addSleepRecord(
                        sleepDate!,
                        sleepTime!,
                        wakeDate!,
                        wakeTime!,
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
