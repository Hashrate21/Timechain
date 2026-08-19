import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../domain/entities/actual_transaction.dart';
import '../../domain/entities/projected_transaction.dart'; // for TransactionType

class ActualTransactionRepository {
  final DatabaseHelper dbHelper;
  final _uuid = const Uuid();

  ActualTransactionRepository(this.dbHelper);

  Future<List<ActualTransaction>> getAll() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'actual_transactions',
      orderBy: 'date DESC',
    );

    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<ActualTransaction>> getByMonth(String yearMonth) async {
    final all = await getAll();
    return all.where((t) {
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      return key == yearMonth;
    }).toList();
  }

  Future<void> insert(ActualTransaction tx) async {
    final db = await dbHelper.database;
    await db.insert('actual_transactions', _toMap(tx));
  }

  Future<void> update(ActualTransaction tx) async {
    final db = await dbHelper.database;
    await db.update(
      'actual_transactions',
      _toMap(tx),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await dbHelper.database;
    await db.delete('actual_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<ActualTransaction> create({
    required DateTime date,
    required String accountId,
    required String name,
    required String categoryId,
    required double amount,
    required TransactionType type,
    String? notes,
  }) async {
    final now = DateTime.now();
    final tx = ActualTransaction(
      id: _uuid.v4(),
      date: date,
      accountId: accountId,
      name: name,
      categoryId: categoryId,
      amount: amount,
      type: type,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    await insert(tx);
    return tx;
  }

  ActualTransaction _fromMap(Map<String, dynamic> map) {
    return ActualTransaction(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      accountId: map['account_id'] as String,
      name: map['name'] as String,
      categoryId: map['category_id'] as String,
      amount: map['amount'] as double,
      type: switch (map['type'] as String) {
        'income' => TransactionType.income,
        'transfer' => TransactionType.transfer,
        _ => TransactionType.expense,
      },          
      notes: map['notes'] as String?,
      transferPairId: map['transfer_pair_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> _toMap(ActualTransaction tx) {
    return {
      'id': tx.id,
      'date': tx.date.toIso8601String(),
      'account_id': tx.accountId,
      'name': tx.name,
      'category_id': tx.categoryId,
      'amount': tx.amount,
      'type': switch (tx.type) {
        TransactionType.income => 'income',
        TransactionType.transfer => 'transfer',
        TransactionType.expense => 'expense',
      },      
      'notes': tx.notes,
      'transfer_pair_id': tx.transferPairId,
      'created_at': tx.createdAt.toIso8601String(),
      'updated_at': tx.updatedAt.toIso8601String(),
    };
  }
}