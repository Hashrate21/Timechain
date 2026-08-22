import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

class CalculatorPresetRepository {
  CalculatorPresetRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<Database> get _db async => _dbHelper.database;

  static String _key(String calculator, String? accountId) {
    if (accountId == null || accountId.isEmpty) {
      return '$calculator:global';
    }
    return '$calculator:$accountId';
  }

  Future<Map<String, dynamic>?> getPreset({
    required String calculator, // 'debt' | 'savings'
    String? accountId,
  }) async {
    final db = await _db;
    final id = _key(calculator, accountId);
    final rows = await db.query(
      'calculator_presets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['payload'] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePreset({
    required String calculator,
    String? accountId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _db;
    final id = _key(calculator, accountId);
    final now = DateTime.now().toIso8601String();
    await db.insert('calculator_presets', {
      'id': id,
      'calculator': calculator,
      'account_id': accountId,
      'payload': jsonEncode(payload),
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
