import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import 'storage_service.dart';

class ExportImportService {
  final StorageService storage;

  ExportImportService(this.storage);

  Future<void> exportData({
    required BuildContext context,
    required Map<DateTime, List<SleepRecord>> sleepData,
    required List<CoffeeRecord> coffeeRecords,
    required List<MedicineRecord> medicineRecords,
    required List<AlcoholRecord> alcoholRecords,
    required List<NoteRecord> noteRecords,
  }) async {
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
    sleepData.forEach((date, records) {
      sleepJson[date.toIso8601String()] = records
          .map((r) => r.toJson())
          .toList();
    });

    final exportData = {
      'version': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'sleepRecords': sleepJson,
      'coffeeRecords': coffeeRecords.map((r) => r.toJson()).toList(),
      'medicineRecords': medicineRecords.map((r) => r.toJson()).toList(),
      'alcoholRecords': alcoholRecords.map((r) => r.toJson()).toList(),
      'noteRecords': noteRecords.map((r) => r.toJson()).toList(),
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
        dialogTitle: 'Save PahingApp Export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(bytes),
      );
      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data exported successfully!')),
        );
      }
    }
  }

  /// Returns imported data or null if cancelled/failed
  Future<ImportedData?> importData(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return null;

    final filePath = result.files.single.path;
    if (filePath == null) return null;

    try {
      final content = await File(filePath).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final sleepJson = data['sleepRecords'] as Map<String, dynamic>? ?? {};
      final newSleepData = <DateTime, List<SleepRecord>>{};
      sleepJson.forEach((key, value) {
        final date = DateTime.parse(key);
        final records = (value as List)
            .map((r) => SleepRecord.fromJson(r as Map<String, dynamic>))
            .toList();
        newSleepData[date] = records;
      });

      final coffeeList = data['coffeeRecords'] as List? ?? [];
      final newCoffeeRecords = coffeeList
          .map((r) => CoffeeRecord.fromJson(r as Map<String, dynamic>))
          .toList();

      final medicineList = data['medicineRecords'] as List? ?? [];
      final newMedicineRecords = medicineList
          .map((r) => MedicineRecord.fromJson(r as Map<String, dynamic>))
          .toList();

      final alcoholList = data['alcoholRecords'] as List? ?? [];
      final newAlcoholRecords = alcoholList
          .map((r) => AlcoholRecord.fromJson(r as Map<String, dynamic>))
          .toList();

      final noteList = data['noteRecords'] as List? ?? [];
      final newNoteRecords = noteList
          .map((r) => NoteRecord.fromJson(r as Map<String, dynamic>))
          .toList();

      return ImportedData(
        sleepData: newSleepData,
        coffeeRecords: newCoffeeRecords,
        medicineRecords: newMedicineRecords,
        alcoholRecords: newAlcoholRecords,
        noteRecords: newNoteRecords,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import failed: Invalid file format')),
        );
      }
      return null;
    }
  }
}

class ImportedData {
  final Map<DateTime, List<SleepRecord>> sleepData;
  final List<CoffeeRecord> coffeeRecords;
  final List<MedicineRecord> medicineRecords;
  final List<AlcoholRecord> alcoholRecords;
  final List<NoteRecord> noteRecords;

  ImportedData({
    required this.sleepData,
    required this.coffeeRecords,
    required this.medicineRecords,
    required this.alcoholRecords,
    required this.noteRecords,
  });
}
