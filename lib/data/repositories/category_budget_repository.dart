import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class CategoryBudgetRepository {
  final DatabaseHelper dbHelper;

  CategoryBudgetRepository(this.dbHelper);

  static String yearMonthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// Budgets for one calendar month: categoryId → amount
  Future<Map<String, double>> getBudgetsForMonth(String yearMonth) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'category_budgets',
      where: 'year_month = ?',
      whereArgs: [yearMonth],
    );

    final result = <String, double>{};
    for (final m in maps) {
      result[m['category_id'] as String] =
          (m['amount'] as num).toDouble();
    }
    return result;
  }

  /// Convenience: current month
  Future<Map<String, double>> getAllBudgets() async {
    return getBudgetsForMonth(yearMonthKey(DateTime.now()));
  }

  Future<double?> getBudget(
    String categoryId, {
    String? yearMonth,
  }) async {
    final ym = yearMonth ?? yearMonthKey(DateTime.now());
    final db = await dbHelper.database;
    final maps = await db.query(
      'category_budgets',
      where: 'category_id = ? AND year_month = ?',
      whereArgs: [categoryId, ym],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return (maps.first['amount'] as num).toDouble();
  }

  Future<void> setBudget({
    required String categoryId,
    required double amount,
    String? yearMonth,
  }) async {
    final ym = yearMonth ?? yearMonthKey(DateTime.now());
    final db = await dbHelper.database;

    await db.insert(
      'category_budgets',
      {
        'id': 'budget_${categoryId}_$ym',
        'category_id': categoryId,
        'year_month': ym,
        'amount': amount,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearBudget(
    String categoryId, {
    String? yearMonth,
  }) async {
    final db = await dbHelper.database;
    if (yearMonth != null) {
      await db.delete(
        'category_budgets',
        where: 'category_id = ? AND year_month = ?',
        whereArgs: [categoryId, yearMonth],
      );
    } else {
      await db.delete(
        'category_budgets',
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );
    }
  }
}