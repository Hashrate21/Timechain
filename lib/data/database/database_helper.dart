import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'budget_paths.dart';
import '../../domain/entities/account.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String? _currentPath;

  DatabaseHelper._init();

  String? get currentPath => _currentPath;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openCurrent();
    return _database!;
  }

  Future<Database> _openCurrent() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _currentPath ??= await BudgetPaths.resolveInitialPath();
    await BudgetPaths.writeLastPath(_currentPath!);

    return openDatabase(
      _currentPath!,
      version: 12,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> _ensureUntrackedAccount(Database db) async {
    final existing = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [Account.untrackedId],
    );
    if (existing.isNotEmpty) return;

    await db.insert('accounts', {
      'id': Account.untrackedId,
      'name': Account.defaultUntrackedName,
      'type': 'untracked',
      'starting_balance': 0,
      'currency': '\$',
      'is_active': 1,
      'sort_order': 9999,
      'created_at': DateTime.now().toIso8601String(),
      'icon_key': 'public_off',
    });
  }

  Future<void> switchToPath(String path) async {
    await close();
    _currentPath = path;
    await BudgetPaths.writeLastPath(path);
    _database = await _openCurrent();
  }

  Future<void> createAndSwitch(String displayName) async {
    final path = await BudgetPaths.pathForNewName(displayName);
    if (await File(path).exists()) {
      throw StateError('A budget named "$displayName" already exists');
    }
    await switchToPath(path);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      try {
        await db.execute(
          "ALTER TABLE settings ADD COLUMN budget_source TEXT DEFAULT 'category'",
        );
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          "ALTER TABLE settings ADD COLUMN show_currency_symbol INTEGER DEFAULT 1",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE settings ADD COLUMN negative_format TEXT DEFAULT 'minus'",
        );
      } catch (_) {}
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS skipped_occurrences (
          occurrence_id TEXT PRIMARY KEY,
          template_id TEXT NOT NULL,
          date TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          "ALTER TABLE settings ADD COLUMN lookback_mode TEXT DEFAULT 'monthStart'",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE settings ADD COLUMN horizon_mode TEXT DEFAULT 'eom'",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE settings ADD COLUMN custom_lookback_start TEXT",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE settings ADD COLUMN custom_horizon_end TEXT",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE settings ADD COLUMN remember_projection_range INTEGER DEFAULT 1",
        );
      } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        await db.execute(
          "ALTER TABLE accounts ADD COLUMN icon_key TEXT NOT NULL DEFAULT 'account_balance'",
        );
      } catch (_) {}
    }
    if (oldVersion < 9) {
      try {
        await db.execute(
          "ALTER TABLE settings ADD COLUMN use_projection_as_default_target INTEGER NOT NULL DEFAULT 1",
        );
      } catch (_) {}
      // Map old exclusive budget_source → new flag
      try {
        await db.execute('''
          UPDATE settings SET use_projection_as_default_target =
            CASE WHEN budget_source = 'category' THEN 0 ELSE 1 END
        ''');
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute(
          "ALTER TABLE settings ADD COLUMN projection_paid_filter TEXT NOT NULL DEFAULT 'all'",
        );
      } catch (_) {}
    }
    if (oldVersion < 11) {
      await db.execute(
        "ALTER TABLE settings ADD COLUMN color_scheme TEXT NOT NULL DEFAULT 'defaultBlue'",
      );
    }
    if (oldVersion < 12) {
      await _ensureUntrackedAccount(db);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        starting_balance REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT '\$',
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        icon_key TEXT NOT NULL DEFAULT 'account_balance'
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        icon TEXT,
        is_income INTEGER NOT NULL DEFAULT 0,
        is_transfer INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE category_budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        year_month TEXT NOT NULL,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE projected_transactions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT NOT NULL,
        account_id TEXT,
        start_date TEXT NOT NULL,
        recurrence TEXT NOT NULL DEFAULT 'none',
        recurrence_day INTEGER,
        recurrence_day_2 INTEGER,
        recurrence_weekday INTEGER,
        recurrence_end TEXT,
        is_paid INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id),
        FOREIGN KEY (account_id) REFERENCES accounts (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE paid_occurrences (
        id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(template_id, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE actual_transactions (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        account_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category_id TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        notes TEXT,
        transfer_pair_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id),
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY DEFAULT 1,
        app_mode TEXT NOT NULL DEFAULT 'combined',
        starting_balance REAL NOT NULL DEFAULT 0,
        safety_buffer REAL NOT NULL DEFAULT 0,
        currency_symbol TEXT NOT NULL DEFAULT '\$',
        default_projection_months INTEGER NOT NULL DEFAULT 3,
        theme_mode TEXT NOT NULL DEFAULT 'dark',
        show_overspend_warning INTEGER NOT NULL DEFAULT 1,
        budget_source TEXT NOT NULL DEFAULT 'category',
        use_projection_as_default_target INTEGER NOT NULL DEFAULT 1,
        show_currency_symbol INTEGER NOT NULL DEFAULT 1,
        negative_format TEXT NOT NULL DEFAULT 'minus',
        lookback_mode TEXT NOT NULL DEFAULT 'monthStart',
        horizon_mode TEXT NOT NULL DEFAULT 'eom',
        custom_lookback_start TEXT,
        custom_horizon_end TEXT,
        remember_projection_range INTEGER NOT NULL DEFAULT 1,
        projection_paid_filter TEXT NOT NULL DEFAULT 'all',
        color_scheme TEXT NOT NULL DEFAULT 'defaultBlue'
      )
    ''');

    await db.insert('settings', {
      'id': 1,
      'app_mode': 'combined',
      'starting_balance': 0.0,
      'safety_buffer': 0.0,
      'currency_symbol': '\$',
      'default_projection_months': 3,
      'theme_mode': 'dark',
      'show_overspend_warning': 1,
      'budget_source': 'category',
      'use_projection_as_default_target': 1,
      'show_currency_symbol': 1,
      'negative_format': 'minus',
      'lookback_mode': 'monthStart',
      'horizon_mode': 'eom',
      'custom_lookback_start': null,
      'custom_horizon_end': null,
      'remember_projection_range': 1,
      'projection_paid_filter': 'all',
      'color_scheme': 'defaultBlue',
    });

    await db.execute('''
      CREATE TABLE skipped_occurrences (
        occurrence_id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    final now = DateTime.now().toIso8601String();

    final defaultCategories = [
      {
        'id': 'cat_salary',
        'name': 'Salary',
        'color': '#22C55E',
        'is_income': 1,
      },
      {
        'id': 'cat_freelance',
        'name': 'Freelance',
        'color': '#10B981',
        'is_income': 1,
      },
      {
        'id': 'cat_other_income',
        'name': 'Other Income',
        'color': '#34D399',
        'is_income': 1,
      },
      {
        'id': 'cat_housing',
        'name': 'Housing',
        'color': '#3B82F6',
        'is_income': 0,
      },
      {
        'id': 'cat_utilities',
        'name': 'Utilities',
        'color': '#8B5CF6',
        'is_income': 0,
      },
      {
        'id': 'cat_food',
        'name': 'Food & Dining',
        'color': '#F59E0B',
        'is_income': 0,
      },
      {
        'id': 'cat_transport',
        'name': 'Transport',
        'color': '#F97316',
        'is_income': 0,
      },
      {
        'id': 'cat_subscriptions',
        'name': 'Subscriptions',
        'color': '#06B6D4',
        'is_income': 0,
      },
      {
        'id': 'cat_entertainment',
        'name': 'Entertainment',
        'color': '#EC4899',
        'is_income': 0,
      },
      {
        'id': 'cat_other_expense',
        'name': 'Other',
        'color': '#64748B',
        'is_income': 0,
      },
      {
        'id': 'cat_transfer',
        'name': 'Transfer',
        'color': '#94A3B8',
        'is_income': 0,
        'is_transfer': 1,
      },
    ];

    for (final cat in defaultCategories) {
      await db.insert('categories', {
        'id': cat['id'],
        'name': cat['name'],
        'color': cat['color'],
        'icon': null,
        'is_income': cat['is_income'],
        'is_transfer': cat['is_transfer'] ?? 0,
        'sort_order': 0,
        'created_at': now,
      });
    }
    await _ensureUntrackedAccount(db);
  }
}
