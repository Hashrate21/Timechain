import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/budget_target.dart';
import '../../core/utils/category_color.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/projected_transaction.dart';
import '../analytics/activity_tab.dart';
import '../analytics/analytics_shared.dart';
import '../analytics/budget_tab.dart';
import '../analytics/comparison_tab.dart';
import '../providers/app_providers.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsTab _tab = AnalyticsTab.budget;

  static const _piePalette = <Color>[
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF6366F1),
    Color(0xFF84CC16),
    Color(0xFF06B6D4),
    Color(0xFFA855F7),
  ];

  CostNature _natureFor(
    Map<String, CostNature> byTemplate,
    String templateId,
  ) => byTemplate[templateId] ?? CostNature.variable;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analyticsMonth = ref.watch(analyticsMonthProvider);
    final year = analyticsMonth.year;
    final month = analyticsMonth.month;
    final ym = '$year-${month.toString().padLeft(2, '0')}';
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);
    final monthLabel = ym;

    final transactionsAsync = ref.watch(actualTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final budgetsAsync = ref.watch(categoryBudgetsProvider(ym));
    final projectedAsync = ref.watch(projectedTransactionsProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final paidIdsAsync = ref.watch(paidOccurrenceIdsProvider);
    final service = ref.watch(projectionServiceProvider);
    final skippedIds =
        ref.watch(skippedOccurrenceIdsProvider).valueOrNull ?? <String>{};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
      child: transactionsAsync.when(
        data: (transactions) {
          return categoriesAsync.when(
            data: (categories) {
              return budgetsAsync.when(
                data: (budgets) {
                  return projectedAsync.when(
                    data: (templates) {
                      final settings =
                          settingsAsync.valueOrNull ?? const AppSettings();
                      final appMode = settings.appMode;
                      final useProjectionDefault =
                          appMode != AppMode.actuals &&
                          settings.useProjectionAsDefaultTarget;
                      final usePaidFill = appMode == AppMode.projection;

                      String money(double v) =>
                          formatMoneyFromSettings(v, settings);
                      String money0(double v) => formatMoney(
                        v,
                        symbol: settings.currencySymbol,
                        showSymbol: settings.showCurrencySymbol,
                        negativeFormat: settings.negativeFormat,
                        decimals: 0,
                      );

                      final showActivity = appMode != AppMode.projection;
                      final showComparison = appMode == AppMode.combined;
                      final paidIds = paidIdsAsync.valueOrNull ?? <String>{};

                      final natureByTemplate = <String, CostNature>{
                        for (final t in templates) t.id: t.costNature,
                      };

                      if ((!showActivity && _tab == AnalyticsTab.activity) ||
                          (!showComparison &&
                              _tab == AnalyticsTab.comparison)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => _tab = AnalyticsTab.budget);
                          }
                        });
                      }

                      // ── spent this month ───────────────────────────
                      final spent = <String, double>{};
                      for (final t in transactions) {
                        if (t.type == TransactionType.expense &&
                            t.date.year == year &&
                            t.date.month == month) {
                          spent[t.categoryId] =
                              (spent[t.categoryId] ?? 0) + t.amount;
                        }
                      }

                      final categoryMap = {for (final c in categories) c.id: c};
                      CategoryColor catCol(String? raw) => CategoryColor.parse(
                        raw ?? '',
                        fallback: colors.primary,
                      );

                      // ── projected this month + F/V mix ─────────────
                      final projectedByCategory = <String, double>{};
                      final projectedPaidByCategory = <String, double>{};
                      double mixFixed = 0;
                      double mixVariable = 0;
                      try {
                        final occ = service.expand(
                          templates: templates,
                          start: monthStart,
                          end: monthEnd,
                        );
                        for (final o in occ) {
                          if (o.type != TransactionType.expense) continue;
                          if (skippedIds.contains(o.id)) continue;
                          projectedByCategory[o.categoryId] =
                              (projectedByCategory[o.categoryId] ?? 0) +
                              o.amount;
                          if (paidIds.contains(o.id)) {
                            projectedPaidByCategory[o.categoryId] =
                                (projectedPaidByCategory[o.categoryId] ?? 0) +
                                o.amount;
                          }
                          final n = _natureFor(natureByTemplate, o.templateId);
                          if (n == CostNature.fixed) {
                            mixFixed += o.amount;
                          } else {
                            mixVariable += o.amount;
                          }
                        }
                      } catch (_) {}

                      // ── last 6 months F/V ──────────────────────────
                      final mixHistory = <FvMonth>[];
                      for (int i = 5; i >= 0; i--) {
                        final monthDate = DateTime(year, month - i, 1);
                        final start = DateTime(
                          monthDate.year,
                          monthDate.month,
                          1,
                        );
                        final end = DateTime(
                          monthDate.year,
                          monthDate.month + 1,
                          0,
                        );
                        double f = 0;
                        double v = 0;
                        try {
                          final occ = service.expand(
                            templates: templates,
                            start: start,
                            end: end,
                          );
                          for (final o in occ) {
                            if (o.type != TransactionType.expense) continue;
                            if (skippedIds.contains(o.id)) continue;
                            final n = _natureFor(
                              natureByTemplate,
                              o.templateId,
                            );
                            if (n == CostNature.fixed) {
                              f += o.amount;
                            } else {
                              v += o.amount;
                            }
                          }
                        } catch (_) {}
                        mixHistory.add(
                          FvMonth(
                            label: monthDate.month.toString().padLeft(2, '0'),
                            fixed: f,
                            variable: v,
                          ),
                        );
                      }

                      // ── budget segments ────────────────────────────
                      final sourceMap = <String, double>{};
                      for (final cat in categories) {
                        if (cat.isIncome || cat.isTransfer) continue;
                        final eff = effectiveTarget(
                          categoryId: cat.id,
                          useProjectionAsDefault: useProjectionDefault,
                          manualBudgets: budgets,
                          projectedByCategory: projectedByCategory,
                        );
                        if (eff.amount > 0) {
                          sourceMap[cat.id] = eff.amount;
                        }
                      }

                      final segments = sourceMap.entries.map((e) {
                        final cat = categoryMap[e.key];
                        final cc = catCol(cat?.color);
                        return Segment(
                          id: e.key,
                          name: cat?.name ?? 'Unknown',
                          amount: e.value,
                          color: cc.start,
                        );
                      }).toList()..sort((a, b) => b.amount.compareTo(a.amount));
                      final total = segments.fold<double>(
                        0,
                        (sum, s) => sum + s.amount,
                      );

                      // ── spend segments ─────────────────────────────
                      final spendSegments =
                          spent.entries.where((e) => e.value > 0).map((e) {
                              final cat = categoryMap[e.key];
                              final cc = catCol(cat?.color);
                              return Segment(
                                id: e.key,
                                name: cat?.name ?? 'Unknown',
                                amount: e.value,
                                color: cc.start,
                              );
                            }).toList()
                            ..sort((a, b) => b.amount.compareTo(a.amount));
                      final spendTotal = spendSegments.fold<double>(
                        0,
                        (sum, s) => sum + s.amount,
                      );

                      // ── description breakdown ──────────────────────
                      final descByCat = <String, Map<String, DescAgg>>{};
                      final txCountByCat = <String, int>{};
                      for (final t in transactions) {
                        if (t.type != TransactionType.expense) continue;
                        if (t.date.year != year || t.date.month != month) {
                          continue;
                        }
                        final raw = t.name.trim();
                        if (raw.isEmpty) continue;
                        final key = raw.toLowerCase();
                        final map = descByCat.putIfAbsent(
                          t.categoryId,
                          () => <String, DescAgg>{},
                        );
                        final existing = map[key];
                        if (existing == null) {
                          map[key] = DescAgg(label: raw, amount: t.amount);
                        } else {
                          map[key] = DescAgg(
                            label: existing.label,
                            amount: existing.amount + t.amount,
                          );
                        }
                        txCountByCat[t.categoryId] =
                            (txCountByCat[t.categoryId] ?? 0) + 1;
                      }

                      final detailCategoryOptions =
                          spent.entries.where((e) => e.value > 0).map((e) {
                              final cat = categoryMap[e.key];
                              return DetailCatOption(
                                id: e.key,
                                name: cat?.name ?? 'Unknown',
                                total: e.value,
                                distinctCount: descByCat[e.key]?.length ?? 0,
                                txCount: txCountByCat[e.key] ?? 0,
                              );
                            }).toList()
                            ..sort((a, b) => b.total.compareTo(a.total));

                      List<DescSlice> slicesFor(String? catId) {
                        if (catId == null) return [];
                        final map = descByCat[catId];
                        if (map == null || map.isEmpty) return [];
                        final catTotal = spent[catId] ?? 0;
                        if (catTotal <= 0) return [];

                        final raw =
                            map.entries
                                .map(
                                  (e) => DescSlice(
                                    id: e.key,
                                    label: e.value.label,
                                    amount: e.value.amount,
                                    color: Colors.grey,
                                    otherParts: const [],
                                  ),
                                )
                                .toList()
                              ..sort((a, b) => b.amount.compareTo(a.amount));

                        final main = <DescSlice>[];
                        final otherParts = <DescSlice>[];
                        double otherSum = 0;
                        for (final s in raw) {
                          final pct = s.amount / catTotal;
                          if (pct < 0.02) {
                            otherParts.add(s);
                            otherSum += s.amount;
                          } else {
                            main.add(s);
                          }
                        }
                        if (otherSum > 0) {
                          main.add(
                            DescSlice(
                              id: '__other__',
                              label: 'Other',
                              amount: otherSum,
                              color: Colors.grey,
                              otherParts: otherParts,
                            ),
                          );
                        }
                        for (var i = 0; i < main.length; i++) {
                          final c = main[i].id == '__other__'
                              ? const Color(0xFF94A3B8)
                              : _piePalette[i % _piePalette.length];
                          main[i] = DescSlice(
                            id: main[i].id,
                            label: main[i].label,
                            amount: main[i].amount,
                            color: c,
                            otherParts: main[i].otherParts,
                          );
                        }
                        return main;
                      }

                      // ── budget performance rows ────────────────────
                      final budgetRows = <BudgetRow>[];
                      for (final cat in categories) {
                        if (cat.isIncome || cat.isTransfer) continue;
                        final eff = effectiveTarget(
                          categoryId: cat.id,
                          useProjectionAsDefault: useProjectionDefault,
                          manualBudgets: budgets,
                          projectedByCategory: projectedByCategory,
                        );
                        if (!eff.hasTarget) continue;
                        final fill = usePaidFill
                            ? (projectedPaidByCategory[cat.id] ?? 0)
                            : (spent[cat.id] ?? 0);
                        budgetRows.add(
                          BudgetRow(
                            id: cat.id,
                            name: cat.name,
                            spent: fill,
                            budget: eff.amount,
                            catColor: catCol(cat.color),
                          ),
                        );
                      }
                      budgetRows.sort((a, b) => b.spent.compareTo(a.spent));
                      final totalSpentFill = budgetRows.fold<double>(
                        0,
                        (s, r) => s + r.spent,
                      );
                      final totalBudget = budgetRows.fold<double>(
                        0,
                        (s, r) => s + r.budget,
                      );

                      final unbudgeted = <MapEntry<String, double>>[];
                      if (!usePaidFill) {
                        for (final e in spent.entries) {
                          if (e.value <= 0) continue;
                          final eff = effectiveTarget(
                            categoryId: e.key,
                            useProjectionAsDefault: useProjectionDefault,
                            manualBudgets: budgets,
                            projectedByCategory: projectedByCategory,
                          );
                          if (eff.hasTarget) continue;
                          final cat = categoryMap[e.key];
                          unbudgeted.add(
                            MapEntry(cat?.name ?? 'Unknown', e.value),
                          );
                        }
                        unbudgeted.sort((a, b) => b.value.compareTo(a.value));
                      }

                      // ── combined rows (comparison) ─────────────────
                      final projectedThisMonth = Map<String, double>.from(
                        projectedByCategory,
                      );
                      final combinedIds = <String>{
                        ...spent.keys,
                        ...budgets.keys,
                        ...projectedThisMonth.keys,
                      };
                      final combinedRows = <CombinedRow>[];
                      for (final id in combinedIds) {
                        final cat = categoryMap[id];
                        if (cat == null || cat.isIncome || cat.isTransfer) {
                          continue;
                        }
                        final cc = catCol(cat.color);
                        final eff = effectiveTarget(
                          categoryId: id,
                          useProjectionAsDefault: useProjectionDefault,
                          manualBudgets: budgets,
                          projectedByCategory: projectedThisMonth,
                        );
                        combinedRows.add(
                          CombinedRow(
                            id: id,
                            name: cat.name,
                            projected: projectedThisMonth[id] ?? 0,
                            actual: spent[id] ?? 0,
                            budget: eff.amount,
                            color: cc.start,
                          ),
                        );
                      }
                      combinedRows.sort((a, b) => b.actual.compareTo(a.actual));

                      // ── monthly proj vs actual ─────────────────────
                      final monthly = <MonthCompare>[];
                      for (int i = 5; i >= 0; i--) {
                        final monthDate = DateTime(year, month - i, 1);
                        final start = DateTime(
                          monthDate.year,
                          monthDate.month,
                          1,
                        );
                        final end = DateTime(
                          monthDate.year,
                          monthDate.month + 1,
                          0,
                        );
                        double actual = 0;
                        for (final t in transactions) {
                          if (t.type == TransactionType.expense &&
                              !t.date.isBefore(start) &&
                              !t.date.isAfter(end)) {
                            actual += t.amount;
                          }
                        }
                        double projected = 0;
                        try {
                          final occ = service.expand(
                            templates: templates,
                            start: start,
                            end: end,
                          );
                          for (final o in occ) {
                            if (o.type == TransactionType.expense) {
                              if (skippedIds.contains(o.id)) continue;
                              projected += o.amount;
                            }
                          }
                        } catch (_) {}
                        monthly.add(
                          MonthCompare(
                            label:
                                '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}',
                            projected: projected,
                            actual: actual,
                          ),
                        );
                      }

                      // ── category trends ────────────────────────────
                      const trendMonths = 6;
                      final trendMonthLabels = <String>[];
                      final perCategoryMonthly = <String, List<double>>{};
                      for (int i = trendMonths - 1; i >= 0; i--) {
                        final monthDate = DateTime(year, month - i, 1);
                        trendMonthLabels.add(
                          monthDate.month.toString().padLeft(2, '0'),
                        );
                        final monthIndex = trendMonths - 1 - i;
                        if (appMode == AppMode.projection) {
                          try {
                            final start = DateTime(
                              monthDate.year,
                              monthDate.month,
                              1,
                            );
                            final end = DateTime(
                              monthDate.year,
                              monthDate.month + 1,
                              0,
                            );
                            final monthYm =
                                '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}';
                            final monthProjected = <String, double>{};
                            final occ = service.expand(
                              templates: templates,
                              start: start,
                              end: end,
                            );
                            for (final o in occ) {
                              if (o.type != TransactionType.expense) {
                                continue;
                              }
                              if (skippedIds.contains(o.id)) continue;
                              monthProjected[o.categoryId] =
                                  (monthProjected[o.categoryId] ?? 0) +
                                  o.amount;
                            }
                            final monthBudgets =
                                ref
                                    .watch(categoryBudgetsProvider(monthYm))
                                    .valueOrNull ??
                                <String, double>{};
                            for (final cat in categories) {
                              if (cat.isIncome || cat.isTransfer) continue;
                              final eff = effectiveTarget(
                                categoryId: cat.id,
                                useProjectionAsDefault: useProjectionDefault,
                                manualBudgets: monthBudgets,
                                projectedByCategory: monthProjected,
                              );
                              if (eff.amount <= 0) continue;
                              perCategoryMonthly.putIfAbsent(
                                cat.id,
                                () => List<double>.filled(trendMonths, 0),
                              );
                              perCategoryMonthly[cat.id]![monthIndex] =
                                  eff.amount;
                            }
                          } catch (_) {}
                        } else {
                          for (final t in transactions) {
                            if (t.type == TransactionType.expense &&
                                t.date.year == monthDate.year &&
                                t.date.month == monthDate.month) {
                              perCategoryMonthly.putIfAbsent(
                                t.categoryId,
                                () => List<double>.filled(trendMonths, 0),
                              );
                              perCategoryMonthly[t.categoryId]![monthIndex] +=
                                  t.amount;
                            }
                          }
                        }
                      }

                      final ranked = perCategoryMonthly.entries.toList()
                        ..sort((a, b) {
                          final ta = a.value.fold<double>(0, (s, v) => s + v);
                          final tb = b.value.fold<double>(0, (s, v) => s + v);
                          return tb.compareTo(ta);
                        });

                      final topTrends = <CategoryTrend>[];
                      for (final e in ranked.take(10)) {
                        final cat = categoryMap[e.key];
                        final cc = catCol(cat?.color);
                        topTrends.add(
                          CategoryTrend(
                            id: e.key,
                            name: cat?.name ?? 'Unknown',
                            color: cc.start,
                            monthly: e.value,
                          ),
                        );
                      }

                      final accounts =
                          ref.watch(accountsProvider).valueOrNull ??
                          <Account>[];
                      final netRows = buildNetTransfers(
                        transactions: transactions,
                        accounts: accounts,
                        year: year,
                        month: month,
                      );

                      // ── UI chrome + tabs ───────────────────────────
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appMode == AppMode.projection
                                ? 'Insights from your projection plan and paid progress.'
                                : 'Spending insights from your actual transactions and projections.',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Previous month',
                                onPressed: () {
                                  final m = ref.read(analyticsMonthProvider);
                                  ref
                                      .read(analyticsMonthProvider.notifier)
                                      .state = DateTime(
                                    m.year,
                                    m.month - 1,
                                  );
                                },
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Text(
                                monthLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Next month',
                                onPressed: () {
                                  final m = ref.read(analyticsMonthProvider);
                                  ref
                                      .read(analyticsMonthProvider.notifier)
                                      .state = DateTime(
                                    m.year,
                                    m.month + 1,
                                  );
                                },
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                              const Spacer(),
                              Text(
                                useProjectionDefault
                                    ? 'Budgets: Projection, unless amount set for category'
                                    : 'Budgets: Category set amounts only',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: useProjectionDefault
                                    ? 'Manual Set on Categories wins. '
                                          'Otherwise that month’s projected total is the target.'
                                    : 'Only amounts Set on Categories are targets. '
                                          'Projection does not fill gaps.',
                                child: Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (showActivity || showComparison) ...[
                            AnalyticsTabBar(
                              tab: _tab,
                              showActivity: showActivity,
                              showComparison: showComparison,
                              onChanged: (t) => setState(() => _tab = t),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              switch (_tab) {
                                AnalyticsTab.budget =>
                                  'Targets and performance for this month',
                                AnalyticsTab.activity => 'What you actually spent and trends over time',
                                AnalyticsTab.comparison =>
                                  'Plan vs reality side-by-side',
                              },
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          switch (_tab) {
                            AnalyticsTab.budget => BudgetTab(
                              monthLabel: monthLabel,
                              appMode: appMode,
                              isDark: isDark,
                              useProjectionDefault: useProjectionDefault,
                              usePaidFill: usePaidFill,
                              money: money,
                              money0: money0,
                              segments: segments,
                              total: total,
                              budgetRows: budgetRows,
                              totalSpentFill: totalSpentFill,
                              totalBudget: totalBudget,
                              unbudgeted: unbudgeted,
                              mixFixed: mixFixed,
                              mixVariable: mixVariable,
                              mixHistory: mixHistory,
                              trendMonthLabels: trendMonthLabels,
                              topTrends: topTrends,
                            ),
                            AnalyticsTab.activity => ActivityTab(
                              monthLabel: monthLabel,
                              appMode: appMode,
                              isDark: isDark,
                              money: money,
                              money0: money0,
                              spendSegments: spendSegments,
                              spendTotal: spendTotal,
                              spent: spent,
                              detailCategoryOptions: detailCategoryOptions,
                              slicesFor: slicesFor,
                              netRows: netRows,
                              trendMonthLabels: trendMonthLabels,
                              topTrends: topTrends,
                            ),
                            AnalyticsTab.comparison => ComparisonTab(
                              isDark: isDark,
                              money0: money0,
                              monthly: monthly,
                              combinedRows: combinedRows,
                            ),
                          },
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('Error: $e'),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Error: $e'),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('Error: $e'),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Text('Error: $e'),
      ),
    );
  }
}
