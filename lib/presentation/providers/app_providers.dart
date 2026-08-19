import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/database/database_helper.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/projected_transaction_repository.dart';
import '../../data/repositories/actual_transaction_repository.dart';
import '../../data/repositories/paid_occurrence_repository.dart';
import '../../data/repositories/category_budget_repository.dart';
import '../../data/repositories/skipped_occurrence_repository.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/projected_transaction.dart';
import '../../domain/entities/actual_transaction.dart';
import '../../domain/services/projection_service.dart';

final activeBudgetPathProvider = StateProvider<String?>((ref) => null);

void invalidateAllBudgetData(WidgetRef ref) {
  ref.invalidate(settingsProvider);
  ref.invalidate(accountsProvider);
  ref.invalidate(categoriesProvider);
  ref.invalidate(projectedTransactionsProvider);
  ref.invalidate(actualTransactionsProvider);
  ref.invalidate(paidOccurrenceIdsProvider);
  ref.invalidate(skippedOccurrenceIdsProvider);
  ref.invalidate(accountBalancesProvider);
  ref.invalidate(categoryBudgetsProvider);
  ref.invalidate(currentMonthCategoryBudgetsProvider);
}

Future<void> switchBudget(WidgetRef ref, String path) async {
  await DatabaseHelper.instance.switchToPath(path);
  ref.read(activeBudgetPathProvider.notifier).state = path;
  invalidateAllBudgetData(ref);
}

Future<void> createBudget(WidgetRef ref, String name) async {
  await DatabaseHelper.instance.createAndSwitch(name);
  ref.read(activeBudgetPathProvider.notifier).state =
      DatabaseHelper.instance.currentPath;
  invalidateAllBudgetData(ref);
}
// ========== DATABASE ==========
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

// ========== REPOSITORIES ==========
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseHelperProvider));
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(databaseHelperProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseHelperProvider));
});

final projectedTransactionRepositoryProvider =
    Provider<ProjectedTransactionRepository>((ref) {
  return ProjectedTransactionRepository(ref.watch(databaseHelperProvider));
});

final actualTransactionRepositoryProvider =
    Provider<ActualTransactionRepository>((ref) {
  return ActualTransactionRepository(ref.watch(databaseHelperProvider));
});

// ========== SETTINGS ==========
final settingsProvider = FutureProvider<AppSettings>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getSettings();
});

// ========== ACCOUNTS ==========
final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final repo = ref.watch(accountRepositoryProvider);
  return repo.getAll();
});

// ========== CATEGORIES ==========
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getAll();
});

// ========== PROJECTED TRANSACTIONS ==========

class ProjectedTransactionsNotifier
    extends AsyncNotifier<List<ProjectedTransaction>> {
  @override
  Future<List<ProjectedTransaction>> build() async {
    final repo = ref.watch(projectedTransactionRepositoryProvider);
    return repo.getAll();
  }

  Future<void> add(ProjectedTransaction tx) async {
    final repo = ref.read(projectedTransactionRepositoryProvider);
    await repo.insert(tx);
    final current = state.value ?? [];
    state = AsyncData([...current, tx]);
  }

  Future<void> updateTransaction(ProjectedTransaction tx) async {
    final repo = ref.read(projectedTransactionRepositoryProvider);
    await repo.update(tx);
    final current = state.value ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.id == tx.id) tx else item
    ]);
  }

  Future<void> delete(String id) async {
    final repo = ref.read(projectedTransactionRepositoryProvider);
    await repo.delete(id);
    final current = state.value ?? [];
    state = AsyncData(current.where((tx) => tx.id != id).toList());
  }

  Future<void> restore(ProjectedTransaction tx) async {
    final repo = ref.read(projectedTransactionRepositoryProvider);
    await repo.insert(tx);
    final current = state.value ?? [];
    state = AsyncData([...current, tx]);
  }
}

final projectedTransactionsProvider = AsyncNotifierProvider<
    ProjectedTransactionsNotifier, List<ProjectedTransaction>>(
  ProjectedTransactionsNotifier.new,
);

final projectedIncomesProvider =
    Provider<AsyncValue<List<ProjectedTransaction>>>((ref) {
  final all = ref.watch(projectedTransactionsProvider);
  return all.whenData(
    (list) => list.where((t) => t.type == TransactionType.income).toList(),
  );
});

final projectedExpensesProvider =
    Provider<AsyncValue<List<ProjectedTransaction>>>((ref) {
  final all = ref.watch(projectedTransactionsProvider);
  return all.whenData(
    (list) => list.where((t) => t.type == TransactionType.expense).toList(),
  );
});

// ========== ACTUAL TRANSACTIONS ==========

class ActualTransactionsNotifier
    extends AsyncNotifier<List<ActualTransaction>> {
  @override
  Future<List<ActualTransaction>> build() async {
    final repo = ref.watch(actualTransactionRepositoryProvider);
    return repo.getAll();
  }

  Future<void> add(ActualTransaction tx) async {
    final repo = ref.read(actualTransactionRepositoryProvider);
    await repo.insert(tx);
    final current = state.value ?? [];
    state = AsyncData([tx, ...current]);
  }

  Future<void> addTransfer({
    required DateTime date,
    required String fromAccountId,
    required String toAccountId,
    required String fromAccountName,
    required String toAccountName,
    required double amount,
  }) async {
    final repo = ref.read(actualTransactionRepositoryProvider);
    final pairId = const Uuid().v4();
    final now = DateTime.now();
    const transferCategoryId = 'cat_transfer';
    final abs = amount.abs();

    final fromLeg = ActualTransaction(
      id: const Uuid().v4(),
      date: date,
      accountId: fromAccountId,
      name: 'Transfer to $toAccountName',
      categoryId: transferCategoryId,
      amount: -abs,
      type: TransactionType.transfer,
      transferPairId: pairId,
      createdAt: now,
      updatedAt: now,
    );

    final toLeg = ActualTransaction(
      id: const Uuid().v4(),
      date: date,
      accountId: toAccountId,
      name: 'Transfer from $fromAccountName',
      categoryId: transferCategoryId,
      amount: abs,
      type: TransactionType.transfer,
      transferPairId: pairId,
      createdAt: now,
      updatedAt: now,
    );

    await repo.insert(fromLeg);
    await repo.insert(toLeg);

    final current = state.value ?? [];
    state = AsyncData([toLeg, fromLeg, ...current]);
  }

  Future<void> updateTransfer({
    required String pairId,
    required DateTime date,
    required String fromAccountId,
    required String toAccountId,
    required String fromAccountName,
    required String toAccountName,
    required double amount,
  }) async {
    final repo = ref.read(actualTransactionRepositoryProvider);
    final current = state.value ?? [];
    final oldLegs =
        current.where((t) => t.transferPairId == pairId).toList();

    for (final leg in oldLegs) {
      await repo.delete(leg.id);
    }

    final now = DateTime.now();
    const transferCategoryId = 'cat_transfer';
    final abs = amount.abs();

    final fromLeg = ActualTransaction(
      id: const Uuid().v4(),
      date: date,
      accountId: fromAccountId,
      name: 'Transfer to $toAccountName',
      categoryId: transferCategoryId,
      amount: -abs,
      type: TransactionType.transfer,
      transferPairId: pairId,
      createdAt: oldLegs.isNotEmpty ? oldLegs.first.createdAt : now,
      updatedAt: now,
    );

    final toLeg = ActualTransaction(
      id: const Uuid().v4(),
      date: date,
      accountId: toAccountId,
      name: 'Transfer from $fromAccountName',
      categoryId: transferCategoryId,
      amount: abs,
      type: TransactionType.transfer,
      transferPairId: pairId,
      createdAt: oldLegs.isNotEmpty ? oldLegs.first.createdAt : now,
      updatedAt: now,
    );

    await repo.insert(fromLeg);
    await repo.insert(toLeg);

    final without = current.where((t) => t.transferPairId != pairId);
    state = AsyncData([toLeg, fromLeg, ...without]);
  }

  Future<void> updateTransaction(ActualTransaction tx) async {
    final repo = ref.read(actualTransactionRepositoryProvider);
    await repo.update(tx);
    final current = state.value ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.id == tx.id) tx else item
    ]);
  }

  /// Returns deleted rows (1 normal, 2 for a transfer pair) for undo.
  Future<List<ActualTransaction>> delete(String id) async {
    final repo = ref.read(actualTransactionRepositoryProvider);
    final current = state.value ?? [];
    ActualTransaction? tx;
    for (final t in current) {
      if (t.id == id) {
        tx = t;
        break;
      }
    }
    if (tx == null) return [];

    if (tx.transferPairId != null) {
      final pairId = tx.transferPairId!;
      final legs =
          current.where((t) => t.transferPairId == pairId).toList();
      for (final leg in legs) {
        await repo.delete(leg.id);
      }
      state = AsyncData(
        current.where((t) => t.transferPairId != pairId).toList(),
      );
      return legs;
    }

    await repo.delete(id);
    state = AsyncData(current.where((t) => t.id != id).toList());
    return [tx];
  }

  Future<void> restore(ActualTransaction tx) async {
    final repo = ref.read(actualTransactionRepositoryProvider);
    await repo.insert(tx);
    final current = state.value ?? [];
    state = AsyncData([tx, ...current]);
  }

  Future<void> restoreMany(List<ActualTransaction> txs) async {
    if (txs.isEmpty) return;
    final repo = ref.read(actualTransactionRepositoryProvider);
    for (final tx in txs) {
      await repo.insert(tx);
    }
    final current = state.value ?? [];
    state = AsyncData([...txs, ...current]);
  }
}

final actualTransactionsProvider = AsyncNotifierProvider<
    ActualTransactionsNotifier, List<ActualTransaction>>(
  ActualTransactionsNotifier.new,
);

// ========== PROJECTION ENGINE ==========

final projectionServiceProvider = Provider<ProjectionService>((ref) {
  return ProjectionService();
});

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Session overrides; hydrated from settings when Projection opens.
final projectionLookbackModeProvider =
    StateProvider<ProjectionLookbackMode>(
  (ref) => ProjectionLookbackMode.monthStart,
);

final projectionHorizonModeProvider =
    StateProvider<ProjectionHorizonMode>(
  (ref) => ProjectionHorizonMode.eom,
);

final projectionCustomStartProvider =
    StateProvider<DateTime?>((ref) => null);

final projectionCustomEndProvider =
    StateProvider<DateTime?>((ref) => null);

/// Wide expand to resolve last/next pay anchors.
final payAnchorOccurrencesProvider =
    Provider<AsyncValue<List<ProjectionOccurrence>>>((ref) {
  final templatesAsync = ref.watch(projectedTransactionsProvider);
  final service = ref.watch(projectionServiceProvider);
  final today = _dateOnly(DateTime.now());

  return templatesAsync.whenData((templates) {
    return service.expand(
      templates: templates,
      start: today.subtract(const Duration(days: 400)),
      end: today.add(const Duration(days: 400)),
    );
  });
});

final canUseLastPayProvider = Provider<bool>((ref) {
  final today = _dateOnly(DateTime.now());
  final payOcc =
      ref.watch(payAnchorOccurrencesProvider).valueOrNull ?? [];
  return payOcc.any(
    (o) =>
        o.type == TransactionType.income &&
        !_dateOnly(o.date).isAfter(today),
  );
});

final canUseNextPayProvider = Provider<bool>((ref) {
  final today = _dateOnly(DateTime.now());
  final payOcc =
      ref.watch(payAnchorOccurrencesProvider).valueOrNull ?? [];
  return payOcc.any(
    (o) =>
        o.type == TransactionType.income &&
        _dateOnly(o.date).isAfter(today),
  );
});

final projectionRangeProvider = Provider<DateTimeRange>((ref) {
  final today = _dateOnly(DateTime.now());
  final lookbackMode = ref.watch(projectionLookbackModeProvider);
  final horizonMode = ref.watch(projectionHorizonModeProvider);
  final customStart = ref.watch(projectionCustomStartProvider);
  final customEnd = ref.watch(projectionCustomEndProvider);
  final payOcc =
      ref.watch(payAnchorOccurrencesProvider).valueOrNull ?? [];

  final incomes = payOcc
      .where((o) => o.type == TransactionType.income)
      .map((o) => _dateOnly(o.date))
      .toList()
    ..sort();

  DateTime start;
  switch (lookbackMode) {
    case ProjectionLookbackMode.monthStart:
      start = DateTime(today.year, today.month, 1);
      break;
    case ProjectionLookbackMode.lastPay:
      final past = incomes.where((d) => !d.isAfter(today)).toList();
      start = past.isEmpty
          ? DateTime(today.year, today.month, 1)
          : past.last;
      break;
    case ProjectionLookbackMode.custom:
      start = customStart != null
          ? _dateOnly(customStart)
          : DateTime(today.year, today.month, 1);
      break;
  }

  DateTime end;
  switch (horizonMode) {
    case ProjectionHorizonMode.eom:
      end = DateTime(today.year, today.month + 1, 0);
      break;
    case ProjectionHorizonMode.nextPay:
      final future = incomes.where((d) => d.isAfter(today)).toList();
      if (future.isEmpty) {
        end = DateTime(today.year, today.month + 1, 0);
      } else {
        // Day before next income lands
        end = future.first.subtract(const Duration(days: 1));
      }
      break;
    case ProjectionHorizonMode.custom:
      end = customEnd != null
          ? _dateOnly(customEnd)
          : DateTime(today.year, today.month + 1, 0);
      break;
  }

  if (end.isBefore(start)) {
    end = start;
  }

  return DateTimeRange(start: start, end: end);
});

bool projectionRangeHydrated = false;

void applyProjectionRangeFromSettings(Ref ref, AppSettings settings) {
  ref.read(projectionLookbackModeProvider.notifier).state =
      settings.lookbackMode;
  ref.read(projectionHorizonModeProvider.notifier).state =
      settings.horizonMode;
  ref.read(projectionCustomStartProvider.notifier).state =
      settings.customLookbackStart;
  ref.read(projectionCustomEndProvider.notifier).state =
      settings.customHorizonEnd;
}

/// Watched by Dashboard + Projection so either screen restores range.
final projectionRangeBootstrapProvider = Provider<void>((ref) {
  final async = ref.watch(settingsProvider);
  async.whenData((settings) {
    if (projectionRangeHydrated) return;
    projectionRangeHydrated = true;
    Future.microtask(() {
      applyProjectionRangeFromSettings(ref, settings);
    });
  });
});

final projectionOccurrencesProvider =
    Provider<AsyncValue<List<ProjectionOccurrence>>>((ref) {
  final templatesAsync = ref.watch(projectedTransactionsProvider);
  final range = ref.watch(projectionRangeProvider);
  final service = ref.watch(projectionServiceProvider);

  return templatesAsync.whenData((templates) {
    return service.expand(
      templates: templates,
      start: range.start,
      end: range.end,
    );
  });
});

final paidOccurrenceRepositoryProvider =
    Provider<PaidOccurrenceRepository>((ref) {
  return PaidOccurrenceRepository(ref.watch(databaseHelperProvider));
});

final paidOccurrenceIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.watch(paidOccurrenceRepositoryProvider);
  return repo.getAllPaidIds();
});

final categoryBudgetRepositoryProvider =
    Provider<CategoryBudgetRepository>((ref) {
  return CategoryBudgetRepository(ref.watch(databaseHelperProvider));
});

final categoryBudgetsProvider =
    FutureProvider.family<Map<String, double>, String>((ref, yearMonth) async {
  final repo = ref.watch(categoryBudgetRepositoryProvider);
  return repo.getBudgetsForMonth(yearMonth);
});

final currentMonthCategoryBudgetsProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final ym = CategoryBudgetRepository.yearMonthKey(DateTime.now());
  return ref.watch(categoryBudgetsProvider(ym).future);
});

final accountBalancesProvider =
    Provider<AsyncValue<Map<String, double>>>((ref) {
  final accountsAsync = ref.watch(accountsProvider);
  final txAsync = ref.watch(actualTransactionsProvider);

  return accountsAsync.when(
    data: (accounts) {
      return txAsync.when(
        data: (transactions) {
          final balances = <String, double>{};

          for (final account in accounts) {
            double balance = account.startingBalance;

            for (final tx in transactions) {
              if (tx.accountId != account.id) continue;

              switch (tx.type) {
                case TransactionType.income:
                  balance += tx.amount;
                case TransactionType.expense:
                  balance -= tx.amount;
                case TransactionType.transfer:
                  balance += tx.amount;
              }
            }

            balances[account.id] = balance;
          }

          return AsyncData(balances);
        },
        loading: () => const AsyncLoading(),
        error: (e, s) => AsyncError(e, s),
      );
    },
    loading: () => const AsyncLoading(),
    error: (e, s) => AsyncError(e, s),
  );
});

final skippedOccurrenceRepositoryProvider =
    Provider<SkippedOccurrenceRepository>((ref) {
  return SkippedOccurrenceRepository(DatabaseHelper.instance);
});

final skippedOccurrenceIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.watch(skippedOccurrenceRepositoryProvider);
  return repo.getSkippedIds();
});

final analyticsMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

enum ActualsRangeMode { thisMonth, lastMonth, custom }

final actualsRangeModeProvider =
    StateProvider<ActualsRangeMode>((ref) => ActualsRangeMode.thisMonth);

final actualsCustomRangeProvider =
    StateProvider<DateTimeRange?>((ref) => null);

DateTime _actualsDateOnly(DateTime d) =>
    DateTime(d.year, d.month, d.day);

final actualsDashboardRangeProvider = Provider<DateTimeRange>((ref) {
  final mode = ref.watch(actualsRangeModeProvider);
  final custom = ref.watch(actualsCustomRangeProvider);
  final now = DateTime.now();

  switch (mode) {
    case ActualsRangeMode.thisMonth:
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0);
      return DateTimeRange(start: start, end: end);
    case ActualsRangeMode.lastMonth:
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0);
      return DateTimeRange(start: start, end: end);
    case ActualsRangeMode.custom:
      if (custom != null) {
        return DateTimeRange(
          start: _actualsDateOnly(custom.start),
          end: _actualsDateOnly(custom.end),
        );
      }
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0);
      return DateTimeRange(start: start, end: end);
  }
});

