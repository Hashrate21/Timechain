import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/budget_target.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/projected_transaction.dart';
import '../providers/app_providers.dart';
import '../widgets/category_treemap.dart';
import '../../core/utils/category_color.dart';

enum _CategoryView { bar, treemap }

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String? _hoveredId;
  String? _selectedId;
  _CategoryView _view = _CategoryView.bar;
  final Set<String> _hiddenTrendIds = {};

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

                      final showProjectedVsActual = appMode == AppMode.combined;
                      final paidIds = paidIdsAsync.valueOrNull ?? <String>{};

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

                      final projectedByCategory = <String, double>{};
                      final projectedPaidByCategory = <String, double>{};
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
                        }
                      } catch (_) {}

                      // Composition = effective targets (Set overrides Projection)
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
                        return _Segment(
                          id: e.key,
                          name: cat?.name ?? 'Unknown',
                          amount: e.value,
                          color: cc.start, // composition/treemap need one color
                        );
                      }).toList()..sort((a, b) => b.amount.compareTo(a.amount));
                      final total = segments.fold<double>(
                        0,
                        (sum, s) => sum + s.amount,
                      );

                      final budgetRows = <_BudgetRow>[];
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
                          _BudgetRow(
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

                      final projectedThisMonth = Map<String, double>.from(
                        projectedByCategory,
                      );

                      final combinedIds = <String>{
                        ...spent.keys,
                        ...budgets.keys,
                        ...projectedThisMonth.keys,
                      };
                      final combinedRows = <_CombinedRow>[];
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
                          _CombinedRow(
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
                      // Projected vs Actual — last 6 months ending at selected
                      final monthly = <_MonthCompare>[];
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
                          _MonthCompare(
                            label:
                                '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}',
                            projected: projected,
                            actual: actual,
                          ),
                        );
                      }

                      // Category trends — top 5, 6 months ending selected
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
                            final occ = service.expand(
                              templates: templates,
                              start: start,
                              end: end,
                            );
                            for (final o in occ) {
                              if (o.type != TransactionType.expense) {
                                if (skippedIds.contains(o.id)) continue;
                                continue;
                              }
                              perCategoryMonthly.putIfAbsent(
                                o.categoryId,
                                () => List<double>.filled(trendMonths, 0),
                              );
                              perCategoryMonthly[o.categoryId]![monthIndex] +=
                                  o.amount;
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

                      final topTrends = <_CategoryTrend>[];
                      for (final e in ranked.take(5)) {
                        final cat = categoryMap[e.key];
                        final cc = catCol(cat?.color);
                        topTrends.add(
                          _CategoryTrend(
                            id: e.key,
                            name: cat?.name ?? 'Unknown',
                            color: cc.start,
                            monthly: e.value,
                          ),
                        );
                      }
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

                          // Month + target source
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

                          // 1. Spending by Category
                          _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Targets by Category',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    _ViewToggle(
                                      view: _view,
                                      onChanged: (v) =>
                                          setState(() => _view = v),
                                    ),
                                    const Spacer(),
                                    Text(
                                      monthLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  total > 0
                                      ? (useProjectionDefault
                                            ? 'Set overrides · gaps from projection · ${money(total)}'
                                            : 'Set amounts only · ${money(total)}')
                                      : (useProjectionDefault
                                            ? 'No budgets yet — add projections or Set budgets'
                                            : 'Set monthly budgets on categories to see targets'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (segments.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    child: Text(
                                      useProjectionDefault
                                          ? 'No budgets yet — add projections or Set amounts on Categories'
                                          : 'Set monthly amounts on Categories to see budgets',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  )
                                else ...[
                                  // Total line (keep yours if you already have it)
                                  Text(
                                    useProjectionDefault
                                        ? 'Set overrides · gaps from projection · ${money0(total)}'
                                        : 'Set amounts only · ${money0(total)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  if (_view == _CategoryView.bar)
                                    SizedBox(
                                      height: 36,
                                      width: double.infinity,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            for (final s in segments)
                                              Expanded(
                                                flex: () {
                                                  final f =
                                                      (s.amount / total * 10000)
                                                          .round();
                                                  return f < 1 ? 1 : f;
                                                }(),
                                                child: Tooltip(
                                                  message:
                                                      '${s.name}: ${money0(s.amount)}',
                                                  child: MouseRegion(
                                                    onEnter: (_) => setState(
                                                      () => _hoveredId = s.id,
                                                    ),
                                                    onExit: (_) => setState(
                                                      () => _hoveredId = null,
                                                    ),
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          _selectedId =
                                                              _selectedId ==
                                                                  s.id
                                                              ? null
                                                              : s.id;
                                                        });
                                                      },
                                                      child: ColoredBox(
                                                        color: () {
                                                          if (_selectedId ==
                                                              null) {
                                                            if (_hoveredId ==
                                                                    null ||
                                                                _hoveredId ==
                                                                    s.id) {
                                                              return s.color;
                                                            }
                                                            return s.color
                                                                .withValues(
                                                                  alpha: 0.35,
                                                                );
                                                          }
                                                          if (_selectedId ==
                                                              s.id) {
                                                            return s.color;
                                                          }
                                                          return s.color
                                                              .withValues(
                                                                alpha: 0.28,
                                                              );
                                                        }(),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      height: 220,
                                      width: double.infinity,
                                      child: CategoryTreemap(
                                        items: [
                                          for (final s in segments)
                                            TreemapItem(
                                              id: s.id,
                                              label: s.name,
                                              value: s.amount,
                                              valueLabel: money0(s.amount),
                                              color: s.color,
                                            ),
                                        ],
                                        selectedId: _selectedId,
                                        hoveredId: _hoveredId,
                                        onHover: (id) =>
                                            setState(() => _hoveredId = id),
                                        onTap: (id) {
                                          setState(() {
                                            _selectedId = _selectedId == id
                                                ? null
                                                : id;
                                          });
                                        },
                                      ),
                                    ),

                                  // legend under the chart (optional — keep your existing legend if you have one)
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      for (final s in segments)
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedId = _selectedId == s.id
                                                  ? null
                                                  : s.id;
                                            });
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: s.color,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${s.name}  ${money0(s.amount)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      _selectedId == s.id
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color:
                                                      _selectedId == null ||
                                                          _selectedId == s.id
                                                      ? null
                                                      : (colors.textSecondary),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 2. Budget Performance
                          _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Budget Performance',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  usePaidFill
                                      ? 'This month · paid vs target (Set or Projection)'
                                      : 'This month · spent vs target (Set or Projection)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (budgetRows.isEmpty && totalSpentFill == 0)
                                  Text(
                                    useProjectionDefault
                                        ? 'No budgets for this month. Add projections or Set budgets on Categories.'
                                        : 'Set monthly budgets on Categories to see performance.',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                    ),
                                  )
                                else ...[
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'Total',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${money0(totalSpentFill)} / ${money0(totalBudget)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    totalBudget > 0 &&
                                                        totalSpentFill >
                                                            totalBudget
                                                    ? AppColors.danger
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final width = constraints.maxWidth;
                                            final over =
                                                totalBudget > 0 &&
                                                totalSpentFill > totalBudget;
                                            final factor = totalBudget > 0
                                                ? (totalSpentFill / totalBudget)
                                                      .clamp(0.0, 1.0)
                                                : 0.0;

                                            return SizedBox(
                                              height: 10,
                                              width: width,
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Stack(
                                                  children: [
                                                    Container(
                                                      color: isDark
                                                          ? Colors.white
                                                                .withValues(
                                                                  alpha: 0.08,
                                                                )
                                                          : Colors.black
                                                                .withValues(
                                                                  alpha: 0.08,
                                                                ),
                                                    ),
                                                    ClipRect(
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        widthFactor: factor,
                                                        child: Container(
                                                          width: width,
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              colors: over
                                                                  ? const [
                                                                      Color(
                                                                        0xFFEF4444,
                                                                      ),
                                                                      Color(
                                                                        0xFFEF4444,
                                                                      ),
                                                                    ]
                                                                  : const [
                                                                      Color(
                                                                        0xFF76ff71,
                                                                      ),
                                                                      Color(
                                                                        0xFFEE850D,
                                                                      ),
                                                                    ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...budgetRows.map((r) {
                                    final progress = (r.spent / r.budget).clamp(
                                      0.0,
                                      1.5,
                                    );
                                    final over = r.spent > r.budget;
                                    final cc = r.catColor;

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  r.name,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${money0(r.spent)} / ${money0(r.budget)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: over
                                                      ? const Color(0xFFEF4444)
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: SizedBox(
                                              height: 8,
                                              width: double.infinity,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  ColoredBox(
                                                    color: isDark
                                                        ? Colors.white
                                                              .withValues(
                                                                alpha: 0.08,
                                                              )
                                                        : Colors.black
                                                              .withValues(
                                                                alpha: 0.08,
                                                              ),
                                                  ),
                                                  FractionallySizedBox(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    widthFactor: progress > 1
                                                        ? 1.0
                                                        : progress,
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        color: over
                                                            ? null
                                                            : (cc.isGradient
                                                                  ? null
                                                                  : cc.start),
                                                        gradient: over
                                                            ? const LinearGradient(
                                                                colors: [
                                                                  Color(
                                                                    0xFFEF4444,
                                                                  ),
                                                                  Color(
                                                                    0xFFF87171,
                                                                  ),
                                                                ],
                                                              )
                                                            : (cc.isGradient
                                                                  ? LinearGradient(
                                                                      colors: [
                                                                        cc.start,
                                                                        cc.end!,
                                                                      ],
                                                                    )
                                                                  : null),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  if (unbudgeted.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'No target',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 16,
                                            runSpacing: 8,
                                            children: [
                                              for (final e in unbudgeted)
                                                Text(
                                                  '${e.key}  ${money0(e.value)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),

                          if (showProjectedVsActual) ...[
                            const SizedBox(height: 20),
                            _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Projected vs Actual',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Expense totals by month (last 6 months)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    height: 220,
                                    child: _ProjectedActualChart(
                                      months: monthly,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      _LegendDot(
                                        color: colors.primary,
                                        label: 'Projected',
                                      ),
                                      SizedBox(width: 16),
                                      _LegendDot(
                                        color: Color(0xFFF59E0B),
                                        label: 'Actual',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Category trends
                          _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Category Trends',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  appMode == AppMode.projection
                                      ? 'Top categories by projected amount (6 months)'
                                      : 'Actual spending by category (6 months)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (topTrends.isEmpty)
                                  Text(
                                    'Not enough data yet',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                    ),
                                  )
                                else ...[
                                  SizedBox(
                                    height: 220,
                                    child: _CategoryTrendsChart(
                                      monthLabels: trendMonthLabels,
                                      trends: [
                                        for (final t in topTrends)
                                          if (!_hiddenTrendIds.contains(t.id))
                                            t,
                                      ],
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Tap a category to show or hide its line',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      for (final t in topTrends)
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (_hiddenTrendIds.contains(
                                                t.id,
                                              )) {
                                                _hiddenTrendIds.remove(t.id);
                                              } else {
                                                final visible =
                                                    topTrends.length -
                                                    _hiddenTrendIds.length;
                                                if (visible <= 1) {
                                                  return;
                                                }
                                                _hiddenTrendIds.add(t.id);
                                              }
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Opacity(
                                            opacity:
                                                _hiddenTrendIds.contains(t.id)
                                                ? 0.35
                                                : 1,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: t.color,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  t.name,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    decoration:
                                                        _hiddenTrendIds
                                                            .contains(t.id)
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (appMode != AppMode.projection) ...[
                            const SizedBox(height: 20),

                            // Plan vs Actual vs Budget
                            _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pojected vs Actual vs Targeted',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Target = Set amount, else projection (if defaults on)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Selected month by category',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'Category',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          'Projected',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          'Actual',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          'Target',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (combinedRows.isEmpty)
                                    Text(
                                      'No data for this month yet',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                      ),
                                    )
                                  else
                                    ...combinedRows.map((r) {
                                      final overBudget =
                                          r.budget > 0 && r.actual > r.budget;
                                      final overPlan =
                                          r.projected > 0 &&
                                          r.actual > r.projected;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: r.color,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      r.name,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 90,
                                              child: Text(
                                                r.projected > 0
                                                    ? money0(r.projected)
                                                    : '—',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 90,
                                              child: Text(
                                                money0(r.actual),
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: overBudget || overPlan
                                                      ? AppColors.danger
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 90,
                                              child: Text(
                                                r.budget > 0
                                                    ? money0(r.budget)
                                                    : '—',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ],
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

// ---------- shared UI / charts / models (same as before) ----------

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final _CategoryView view;
  final ValueChanged<_CategoryView> onChanged;
  const _ViewToggle({required this.view, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: 'Bar',
            selected: view == _CategoryView.bar,
            onTap: () => onChanged(_CategoryView.bar),
          ),
          _ToggleChip(
            label: 'Treemap',
            selected: view == _CategoryView.treemap,
            onTap: () => onChanged(_CategoryView.treemap),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ProjectedActualChart extends StatelessWidget {
  final List<_MonthCompare> months;
  final bool isDark;
  const _ProjectedActualChart({required this.months, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    double maxY = 0;
    for (final m in months) {
      if (m.projected > maxY) maxY = m.projected;
      if (m.actual > maxY) maxY = m.actual;
    }
    if (maxY <= 0) maxY = 100;
    maxY *= 1.15;
    const actualColor = Color(0xFFF59E0B);

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final m = months[group.x.toInt()];
              final isProjected = rodIndex == 0;
              final value = isProjected ? m.projected : m.actual;
              final name = isProjected ? 'Projected' : 'Actual';
              return BarTooltipItem(
                '$name\n${value.toStringAsFixed(0)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value >= meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(fontSize: 10, color: colors.textSecondary),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) {
                  return const SizedBox.shrink();
                }
                final parts = months[i].label.split('-');
                final mm = parts.length > 1 ? parts[1] : months[i].label;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    mm,
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: months[i].projected,
                  color: colors.primary,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                BarChartRodData(
                  toY: months[i].actual,
                  color: actualColor,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryTrendsChart extends StatelessWidget {
  final List<String> monthLabels;
  final List<_CategoryTrend> trends;
  final bool isDark;
  const _CategoryTrendsChart({
    required this.monthLabels,
    required this.trends,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (trends.isEmpty || monthLabels.isEmpty) {
      return const SizedBox.shrink();
    }
    double maxY = 0;
    for (final t in trends) {
      for (final v in t.monthly) {
        if (v > maxY) maxY = v;
      }
    }
    if (maxY <= 0) maxY = 100;
    maxY *= 1.15;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (monthLabels.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((s) {
                final idx = s.barIndex;
                if (idx < 0 || idx >= trends.length) return null;
                final trend = trends[idx];
                return LineTooltipItem(
                  '${trend.name}\n${s.y.toStringAsFixed(0)}',
                  TextStyle(
                    color: trend.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value >= meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(fontSize: 10, color: colors.textSecondary),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= monthLabels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    monthLabels[i],
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          for (int i = 0; i < trends.length; i++)
            LineChartBarData(
              spots: [
                for (int m = 0; m < trends[i].monthly.length; m++)
                  FlSpot(m.toDouble(), trends[i].monthly[m]),
              ],
              isCurved: true,
              color: trends[i].color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
        ],
      ),
    );
  }
}

class _Segment {
  final String id;
  final String name;
  final double amount;
  final Color color;
  _Segment({
    required this.id,
    required this.name,
    required this.amount,
    required this.color,
  });
}

class _BudgetRow {
  final String id;
  final String name;
  final double spent;
  final double budget;
  final CategoryColor catColor;

  _BudgetRow({
    required this.id,
    required this.name,
    required this.spent,
    required this.budget,
    required this.catColor,
  });
}

class _MonthCompare {
  final String label;
  final double projected;
  final double actual;
  _MonthCompare({
    required this.label,
    required this.projected,
    required this.actual,
  });
}

class _CategoryTrend {
  final String id;
  final String name;
  final Color color;
  final List<double> monthly;
  _CategoryTrend({
    required this.id,
    required this.name,
    required this.color,
    required this.monthly,
  });
}

class _CombinedRow {
  final String id;
  final String name;
  final double projected;
  final double actual;
  final double budget;
  final Color color;
  _CombinedRow({
    required this.id,
    required this.name,
    required this.projected,
    required this.actual,
    required this.budget,
    required this.color,
  });
}
