import '../database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class PaidOccurrenceRepository {
  final DatabaseHelper dbHelper;

  PaidOccurrenceRepository(this.dbHelper);

  Future<Set<String>> getAllPaidIds() async {
    final db = await dbHelper.database;
    final maps = await db.query('paid_occurrences');

    return maps.map((m) => m['id'] as String).toSet();
  }

  Future<void> markPaid({
    required String occurrenceId,
    required String templateId,
    required DateTime date,
  }) async {
    final db = await dbHelper.database;
    await db.insert(
      'paid_occurrences',
      {
        'id': occurrenceId,
        'template_id': templateId,
        'date': date.toIso8601String().substring(0, 10),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markUnpaid(String occurrenceId) async {
    final db = await dbHelper.database;
    await db.delete(
      'paid_occurrences',
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
  }
}