import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class ShareService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(12, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Upload all sleep diary data to Firestore and return a share token.
  Future<String> shareData({
    required Map<DateTime, List<SleepRecord>> sleepData,
    required List<CoffeeRecord> coffeeRecords,
    required List<MedicineRecord> medicineRecords,
    required List<AlcoholRecord> alcoholRecords,
    required List<NoteRecord> noteRecords,
  }) async {
    try {
      final token = _generateToken();

      final sleepJson = <String, dynamic>{};
      sleepData.forEach((date, records) {
        sleepJson[date.toIso8601String()] =
            records.map((r) => r.toJson()).toList();
      });

      final expiresAt = Timestamp.fromDate(DateTime.now().add(const Duration(days: 7)));
      await _db.collection('shared').doc(token).set({
        'sleepRecords': sleepJson,
        'coffeeRecords': coffeeRecords.map((r) => r.toJson()).toList(),
        'medicineRecords': medicineRecords.map((r) => r.toJson()).toList(),
        'alcoholRecords': alcoholRecords.map((r) => r.toJson()).toList(),
        'noteRecords': noteRecords.map((r) => r.toJson()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt,
      });

      return token;
    } catch (e) {
      throw Exception('Failed to upload data to Firestore: $e');
    }
  }

  /// Build the shareable URL from a token.
  static String shareUrl(String token) {
    return 'https://pahingapp-sleep.web.app/share/$token';
  }
}
