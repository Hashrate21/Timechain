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

  /// All accounts including untracked (transfer pickers, settings, CSV).
  Future<List<Account>> getAll() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'accounts',
      orderBy: 'sort_order ASC, name ASC',
    );
    return maps.map(_fromMap).toList();
  }

  /// Accounts screen + net worth — excludes untracked.
  Future<List<Account>> getTracked() async {
    final all = await getAll();
    return all.where((a) => !a.isUntracked && a.isActive).toList();
  }

  Future<List<Account>> getActiveUntracked() async {
    final all = await getAll();
    return all.where((a) => a.isUntracked && a.isActive).toList();
  }

  Future<int> countActiveUntracked() async {
    return (await getActiveUntracked()).length;
  }

  /// Prefer first active untracked (seed or any). Used as soft default.
  Future<Account?> getUntracked() async {
    final list = await getActiveUntracked();
    if (list.isEmpty) return null;
    for (final a in list) {
      if (a.id == Account.untrackedId) return a;
    }
    return list.first;
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

  /// Kept for Settings compatibility; prefers system id if present.
  Future<void> renameUntracked(String name) async {
    await ensureUntrackedExists();
    final trimmed = name.trim().isEmpty
        ? Account.defaultUntrackedName
        : name.trim();
    final current = await getUntracked();
    if (current == null) return;
    await update(current.copyWith(name: trimmed));
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
    final db = await dbHelper.database;
    final balance = account.isUntracked ? 0.0 : account.startingBalance;
    await db.update(
      'accounts',
      {
        'name': account.name,
        'type': _typeToDb(account.type),
        'starting_balance': balance,
        'currency': account.currency,
        'is_active': account.isActive ? 1 : 0,
        'sort_order': account.sortOrder,
        'icon_key': account.iconKey,
      },
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  /// Soft-deactivate. Cannot archive the last active untracked account.
  Future<void> archive(String id) async {
    final all = await getAll();
    Account? target;
    for (final a in all) {
      if (a.id == id) {
        target = a;
        break;
      }
    }
    if (target == null) return;

    if (target.isUntracked && target.isActive) {
      final activeCount = all.where((a) => a.isUntracked && a.isActive).length;
      if (activeCount <= 1) {
        throw StateError('Keep at least one untracked account');
      }
    }

    await update(target.copyWith(isActive: false));
  }

  Future<void> restore(Account account) async {
    await update(account.copyWith(isActive: true));
  }

  /// Tracked: hard delete. Untracked: archive (last-untracked guarded).
  Future<void> delete(String id) async {
    final all = await getAll();
    Account? target;
    for (final a in all) {
      if (a.id == id) {
        target = a;
        break;
      }
    }
    if (target == null) return;

    if (target.isUntracked) {
      await archive(id);
      return;
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
    final account = Account(
      id: _uuid.v4(),
      name: name.trim(),
      type: type,
      startingBalance: type == AccountType.untracked ? 0.0 : startingBalance,
      createdAt: DateTime.now(),
      iconKey: iconKey ?? Account.defaultIconFor(type),
    );
    await insert(account);
    return account;
  }
}
