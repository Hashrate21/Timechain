import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../domain/entities/projected_transaction.dart';

class ProjectedTransactionRepository {
  final DatabaseHelper dbHelper;
  final _uuid = const Uuid();

  ProjectedTransactionRepository(this.dbHelper);

  Future<List<ProjectedTransaction>> getAll() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'projected_transactions',
      orderBy: 'start_date ASC, sort_order ASC',
    );

    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<ProjectedTransaction>> getByType(TransactionType type) async {
    final all = await getAll();
    return all.where((t) => t.type == type).toList();
  }

  Future<void> insert(ProjectedTransaction tx) async {
    final db = await dbHelper.database;
    await db.insert('projected_transactions', _toMap(tx));
  }

  Future<void> update(ProjectedTransaction tx) async {
    final db = await dbHelper.database;
    await db.update(
      'projected_transactions',
      _toMap(tx),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await dbHelper.database;
    await db.delete('projected_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<ProjectedTransaction> create({
    required String name,
    required double amount,
    required TransactionType type,
    required String categoryId,
    String? accountId,
    required DateTime startDate,
    RecurrenceType recurrence = RecurrenceType.none,
    int? recurrenceDay,
    int? recurrenceDay2,
    int? recurrenceWeekday,
    DateTime? recurrenceEnd,
    String? notes,
  }) async {
    final tx = ProjectedTransaction(
      id: _uuid.v4(),
      name: name,
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      startDate: startDate,
      recurrence: recurrence,
      recurrenceDay: recurrenceDay,
      recurrenceDay2: recurrenceDay2,
      recurrenceWeekday: recurrenceWeekday,
      recurrenceEnd: recurrenceEnd,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await insert(tx);
    return tx;
  }

  ProjectedTransaction _fromMap(Map<String, dynamic> map) {
    return ProjectedTransaction(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: map['amount'] as double,
      type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      categoryId: map['category_id'] as String,
      accountId: map['account_id'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      recurrence: RecurrenceType.values.firstWhere(
        (e) => e.name == map['recurrence'],
        orElse: () => RecurrenceType.none,
      ),
      recurrenceDay: map['recurrence_day'] as int?,
      recurrenceDay2: map['recurrence_day_2'] as int?,
      recurrenceWeekday: map['recurrence_weekday'] as int?,
      recurrenceEnd: map['recurrence_end'] != null
          ? DateTime.parse(map['recurrence_end'] as String)
          : null,
      isPaid: (map['is_paid'] as int) == 1,
      notes: map['notes'] as String?,
      sortOrder: map['sort_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> _toMap(ProjectedTransaction tx) {
    return {
      'id': tx.id,
      'name': tx.name,
      'amount': tx.amount,
      'type': tx.type == TransactionType.income ? 'income' : 'expense',
      'category_id': tx.categoryId,
      'account_id': tx.accountId,
      'start_date': tx.startDate.toIso8601String(),
      'recurrence': tx.recurrence.name,
      'recurrence_day': tx.recurrenceDay,
      'recurrence_day_2': tx.recurrenceDay2,
      'recurrence_weekday': tx.recurrenceWeekday,
      'recurrence_end': tx.recurrenceEnd?.toIso8601String(),
      'is_paid': tx.isPaid ? 1 : 0,
      'notes': tx.notes,
      'sort_order': tx.sortOrder,
      'created_at': tx.createdAt.toIso8601String(),
    };
  }
}