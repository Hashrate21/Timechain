import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../../domain/entities/account.dart';

class AccountRepository {
  final DatabaseHelper dbHelper;
  final _uuid = const Uuid();

  AccountRepository(this.dbHelper);

  AccountType _typeFromDb(String? raw) {
    switch (raw) {
      case 'liability':
        return AccountType.liability;
      case 'untracked':
        return AccountType.untracked;
      default:
        return AccountType.asset;
    }
  }

  String _typeToDb(AccountType type) {
    switch (type) {
      case AccountType.liability:
        return 'liability';
      case AccountType.untracked:
        return 'untracked';
      case AccountType.asset:
        return 'asset';
    }
  }

  Account _fromMap(Map<String, Object?> map) {
    final type = _typeFromDb(map['type'] as String?);
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      type: type,
      startingBalance: (map['starting_balance'] as num).toDouble(),
      currency: map['currency'] as String? ?? '\$',
      isActive: (map['is_active'] as int?) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      iconKey: map['icon_key'] as String? ?? Account.defaultIconFor(type),
    );
  }

  /// All accounts including Untracked (for transfer pickers, rename).
  Future<List<Account>> getAll() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'accounts',
      orderBy: 'sort_order ASC, name ASC',
    );
    return maps.map(_fromMap).toList();
  }

  /// Accounts screen + net worth — excludes Untracked.
  Future<List<Account>> getTracked() async {
    final all = await getAll();
    return all.where((a) => !a.isUntracked).toList();
  }

  Future<Account?> getUntracked() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [Account.untrackedId],
    );
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<void> ensureUntrackedExists() async {
    final u = await getUntracked();
    if (u != null) return;
    await insert(
      Account(
        id: Account.untrackedId,
        name: Account.defaultUntrackedName,
        type: AccountType.untracked,
        startingBalance: 0,
        sortOrder: 9999,
        createdAt: DateTime.now(),
        iconKey: Account.defaultIconFor(AccountType.untracked),
      ),
    );
  }

  Future<void> renameUntracked(String name) async {
    await ensureUntrackedExists();
    final trimmed = name.trim().isEmpty
        ? Account.defaultUntrackedName
        : name.trim();
    final db = await dbHelper.database;
    await db.update(
      'accounts',
      {'name': trimmed},
      where: 'id = ?',
      whereArgs: [Account.untrackedId],
    );
  }

  Future<void> insert(Account account) async {
    final db = await dbHelper.database;
    await db.insert('accounts', {
      'id': account.id,
      'name': account.name,
      'type': _typeToDb(account.type),
      'starting_balance': account.isUntracked ? 0.0 : account.startingBalance,
      'currency': account.currency,
      'is_active': account.isActive ? 1 : 0,
      'sort_order': account.sortOrder,
      'created_at': account.createdAt.toIso8601String(),
      'icon_key': account.iconKey,
    });
  }

  Future<void> update(Account account) async {
    if (account.isUntracked) {
      // Only name (and safe fields) — never type/balance games
      await renameUntracked(account.name);
      return;
    }
    final db = await dbHelper.database;
    await db.update(
      'accounts',
      {
        'name': account.name,
        'type': _typeToDb(account.type),
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
    if (id == Account.untrackedId) {
      throw StateError('Cannot delete the Untracked account');
    }
    final db = await dbHelper.database;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<Account> create({
    required String name,
    required AccountType type,
    double startingBalance = 0.0,
    String? iconKey,
  }) async {
    if (type == AccountType.untracked) {
      throw StateError('Use ensureUntrackedExists / renameUntracked');
    }
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
