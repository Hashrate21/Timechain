import '../database/database_helper.dart';
import '../../domain/entities/transaction.dart';

class TransactionRepository {
  final DatabaseHelper dbHelper;

  TransactionRepository(this.dbHelper);

  Future<List<Transaction>> getAll() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'transactions',
      orderBy: 'date ASC, sortOrder ASC',
    );

    return maps.map((map) {
      return Transaction(
        id: map['id'] as String,
        name: map['name'] as String,
        amount: map['amount'] as double,
        type: map['type'] == 'income'
            ? TransactionType.income
            : TransactionType.expense,
        category: map['category'] as String,
        date: DateTime.parse(map['date'] as String),
        isRecurring: (map['isRecurring'] as int) == 1,
        recurrence: map['recurrence'] as String?,
        isPaid: (map['isPaid'] as int) == 1,
        sortOrder: map['sortOrder'] as int,
      );
    }).toList();
  }

  Future<List<Transaction>> getByType(TransactionType type) async {
    final all = await getAll();
    return all.where((t) => t.type == type).toList();
  }

  Future<void> insert(Transaction transaction) async {
    final db = await dbHelper.database;
    await db.insert('transactions', {
      'id': transaction.id,
      'name': transaction.name,
      'amount': transaction.amount,
      'type': transaction.type == TransactionType.income ? 'income' : 'expense',
      'category': transaction.category,
      'date': transaction.date.toIso8601String(),
      'isRecurring': transaction.isRecurring ? 1 : 0,
      'recurrence': transaction.recurrence,
      'isPaid': transaction.isPaid ? 1 : 0,
      'sortOrder': transaction.sortOrder,
    });
  }

  Future<void> delete(String id) async {
    final db = await dbHelper.database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}