import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/database_helper.dart';

class SkippedOccurrenceRepository {
  final DatabaseHelper dbHelper;

  SkippedOccurrenceRepository(this.dbHelper);

  Future<Set<String>> getSkippedIds() async {
    final db = await dbHelper.database;
    final rows = await db.query('skipped_occurrences');
    return rows.map((r) => r['occurrence_id'] as String).toSet();
  }

  Future<void> markSkipped({
    required String occurrenceId,
    required String templateId,
    required DateTime date,
  }) async {
    final db = await dbHelper.database;
    await db.insert(
      'skipped_occurrences',
      {
        'occurrence_id': occurrenceId,
        'template_id': templateId,
        'date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markUnskipped(String occurrenceId) async {
    final db = await dbHelper.database;
    await db.delete(
      'skipped_occurrences',
      where: 'occurrence_id = ?',
      whereArgs: [occurrenceId],
    );
  }
}