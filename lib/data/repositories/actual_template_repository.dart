import 'package:uuid/uuid.dart';

import '../../domain/entities/actual_template.dart';
import '../../domain/entities/projected_transaction.dart';
import '../database/database_helper.dart';

class ActualTemplateRepository {
  final dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

  Future<List<ActualTemplate>> getAll() async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'actual_templates',
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<ActualTemplate> create({
    required String name,
    required String description,
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String accountId,
    String? notes,
  }) async {
    if (type == TransactionType.transfer) {
      throw StateError('Templates are income/expense only');
    }
    final t = ActualTemplate(
      id: _uuid.v4(),
      name: name.trim(),
      description: description.trim(),
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      notes: notes,
      createdAt: DateTime.now(),
    );
    final db = await dbHelper.database;
    await db.insert('actual_templates', _toRow(t));
    return t;
  }

  Future<void> delete(String id) async {
    final db = await dbHelper.database;
    await db.delete('actual_templates', where: 'id = ?', whereArgs: [id]);
  }

  ActualTemplate _fromRow(Map<String, Object?> r) {
    return ActualTemplate(
      id: r['id'] as String,
      name: r['name'] as String,
      description: r['description'] as String,
      amount: (r['amount'] as num).toDouble(),
      type: (r['type'] as String) == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      categoryId: r['category_id'] as String,
      accountId: r['account_id'] as String,
      notes: r['notes'] as String?,
      sortOrder: r['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(r['created_at'] as String),
    );
  }

  Map<String, Object?> _toRow(ActualTemplate t) => {
    'id': t.id,
    'name': t.name,
    'description': t.description,
    'amount': t.amount,
    'type': t.type == TransactionType.income ? 'income' : 'expense',
    'category_id': t.categoryId,
    'account_id': t.accountId,
    'notes': t.notes,
    'sort_order': t.sortOrder,
    'created_at': t.createdAt.toIso8601String(),
  };
}
