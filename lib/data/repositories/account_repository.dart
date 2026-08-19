import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../domain/entities/account.dart';

class AccountRepository {
  final DatabaseHelper dbHelper;
  final _uuid = const Uuid();

  AccountRepository(this.dbHelper);

  Future<List<Account>> getAll() async {
    final db = await dbHelper.database;
    final maps =
        await db.query('accounts', orderBy: 'sort_order ASC, name ASC');

    return maps.map((map) {
      final type = map['type'] == 'liability'
          ? AccountType.liability
          : AccountType.asset;
      return Account(
        id: map['id'] as String,
        name: map['name'] as String,
        type: type,
        startingBalance: (map['starting_balance'] as num).toDouble(),
        currency: map['currency'] as String? ?? '\$',
        isActive: (map['is_active'] as int?) == 1,
        sortOrder: map['sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        iconKey: map['icon_key'] as String? ??
            Account.defaultIconFor(type),
      );
    }).toList();
  }

  Future<void> insert(Account account) async {
    final db = await dbHelper.database;
    await db.insert('accounts', {
      'id': account.id,
      'name': account.name,
      'type':
          account.type == AccountType.liability ? 'liability' : 'asset',
      'starting_balance': account.startingBalance,
      'currency': account.currency,
      'is_active': account.isActive ? 1 : 0,
      'sort_order': account.sortOrder,
      'created_at': account.createdAt.toIso8601String(),
      'icon_key': account.iconKey,
    });
  }

  Future<void> update(Account account) async {
    final db = await dbHelper.database;
    await db.update(
      'accounts',
      {
        'name': account.name,
        'type':
            account.type == AccountType.liability ? 'liability' : 'asset',
        'starting_balance': account.startingBalance,
        'currency': account.currency,
        'is_active': account.isActive ? 1 : 0,
        'sort_order': account.sortOrder,
        'icon_key': account.iconKey,
      },
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await dbHelper.database;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<Account> create({
    required String name,
    required AccountType type,
    double startingBalance = 0.0,
    String? iconKey,
  }) async {
    final account = Account(
      id: _uuid.v4(),
      name: name,
      type: type,
      startingBalance: startingBalance,
      createdAt: DateTime.now(),
      iconKey: iconKey ?? Account.defaultIconFor(type),
    );
    await insert(account);
    return account;
  }
}