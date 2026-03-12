import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class StorageService {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Theme
  bool get isDarkMode => _prefs.getBool('nightMode') ?? false;
  Future<void> setDarkMode(bool value) => _prefs.setBool('nightMode', value);

  // Sleep data
  Map<DateTime, List<SleepRecord>> loadSleepData() {
    final sleepData = _prefs.getString('sleepData') ?? '{}';
    final sleepJson = jsonDecode(sleepData) as Map<String, dynamic>;
    final result = <DateTime, List<SleepRecord>>{};
    sleepJson.forEach((key, value) {
      final date = DateTime.parse(key);
      final records = (value as List)
          .map((r) => SleepRecord.fromJson(r as Map<String, dynamic>))
          .toList();
      result[date] = records;
    });
    return result;
  }

  Future<void> saveSleepData(Map<DateTime, List<SleepRecord>> sleepData) async {
    final json = <String, dynamic>{};
    sleepData.forEach((date, records) {
      json[date.toIso8601String()] = records.map((r) => r.toJson()).toList();
    });
    await _prefs.setString('sleepData', jsonEncode(json));
  }

  // Coffee records
  List<CoffeeRecord> loadCoffeeRecords() {
    final data = _prefs.getString('coffeeRecords');
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((r) => CoffeeRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCoffeeRecords(List<CoffeeRecord> records) async {
    await _prefs.setString(
      'coffeeRecords',
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  // Medicine records
  List<MedicineRecord> loadMedicineRecords() {
    final data = _prefs.getString('medicineRecords');
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((r) => MedicineRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveMedicineRecords(List<MedicineRecord> records) async {
    await _prefs.setString(
      'medicineRecords',
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  // Alcohol records
  List<AlcoholRecord> loadAlcoholRecords() {
    final data = _prefs.getString('alcoholRecords');
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((r) => AlcoholRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAlcoholRecords(List<AlcoholRecord> records) async {
    await _prefs.setString(
      'alcoholRecords',
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }
}
