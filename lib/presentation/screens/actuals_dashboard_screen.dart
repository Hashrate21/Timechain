import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/actual_transaction.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/projected_transaction.dart';
import '../providers/app_providers.dart';

enum _InsightWindow { month, days14, days30 }

class ActualsDashboardScreen extends ConsumerStatefulWidget {
  const ActualsDashboardScreen({super.key});

  @override
  ConsumerState<ActualsDashboardScreen> createState() =>
      _ActualsDashboardScreenState();
}

class _ActualsDashboardScreenState
    extends ConsumerState<ActualsDashboardScreen> {
  _InsightWindow _window = _InsightWindow.month;

  static const _monthShortNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _fmtRange(DateTime a, DateTime b) {
    String f(DateTime d) =>
        '${_monthShortNames[d.month - 1]} ${d.day}, ${d.year}';
    return '${f(a)}  →  ${f(b)}';
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final initial =
        ref.read(actualsCustomRangeProvider) ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: initial,
    );
    if (picked == null) return;
    ref.read(actualsCustomRangeProvider.notifier).state = picked;
    ref.read(actualsRangeModeProvider.notifier).state = ActualsRangeMode.custom;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(actualTransactionsProvider);
    final balancesAsync = ref.watch(accountBalancesProvider);
    final projectedAsync = ref.watch(projectedTransactionsProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final service = ref.watch(projectionServiceProvider);
    final range = ref.watch(actualsDashboardRangeProvider);
    final rangeMode = ref.watch(actualsRangeModeProvider);
    final skippedIds =
        ref.watch(skippedOccurrenceIdsProvider).valueOrNull ?? <String>{};

    return transactionsAsync.when(
      data: (transactions) {
        return accountsAsync.when(
          data: (accounts) {
            return projectedAsync.when(
              data: (templates) {
                return balancesAsync.when(
                  data: (balances) {
                    final trackedAccounts = accounts
                        .where((a) => !a.isUntracked)
                        .toList();
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final monthStart = DateTime(now.year, now.month, 1);
                    final monthEnd = DateTime(now.year, now.month + 1, 0);

                    final rangeStart = DateTime(
                      range.start.year,
                      range.start.month,
                      range.start.day,
                    );
                    final rangeEnd = DateTime(
                      range.end.year,
                      range.end.month,
                      range.end.day,
                    );

                    final categoryNames = <String, String>{
                      for (final c in categoriesAsync.valueOrNull ?? [])
                        c.id: c.name,
                    };

                    final settings = settingsAsync.valueOrNull;
                    final isCombined = settings?.appMode == AppMode.combined;
                    final showPlan = isCombined;
                    final s = settings ?? const AppSettings();
                    String money(double v) => formatMoneyFromSettings(v, s);

                    double rangeIncome = 0;
                    double rangeExpense = 0;
                    for (final t in transactions) {
                      final d = DateTime(t.date.year, t.date.month, t.date.day);
                      if (d.isBefore(rangeStart) || d.isAfter(rangeEnd)) {
                        continue;
                      }
                      if (t.type == TransactionType.income) {
                        rangeIncome += t.amount;
                      } else if (t.type == TransactionType.expense) {
                        rangeExpense += t.amount;
                      }
                    }
                    final net = rangeIncome - rangeExpense;

                    double plannedIncome = 0;
                    double plannedExpense = 0;
                    if (showPlan) {
                      try {
                        final occ = service.expand(
                          templates: templates,
                          start: rangeStart,
                          end: rangeEnd,
                        );
                        for (final o in occ) {
                          if (skippedIds.contains(o.id)) continue;
                          if (o.type == TransactionType.income) {
                            plannedIncome += o.amount;
                          } else if (o.type == TransactionType.expense) {
                            plannedExpense += o.amount;
                          }
                        }
                      } catch (_) {}
                    }

                    double netWorth = 0;
                    for (final a in trackedAccounts) {
                      netWorth += balances[a.id] ?? a.startingBalance;
                    }

                    final recent = [...transactions]
                      ..sort((a, b) => b.date.compareTo(a.date));
                    final recentTop = recent.take(6).toList();

                    final insightRange = _rangeForWindow(
                      window: _window,
                      today: today,
                      monthStart: monthStart,
                      monthEnd: monthEnd,
                    );
                    final snapshot = _spendingSnapshot(
                      transactions: transactions,
                      start: insightRange.$1,
                      end: insightRange.$2,
                      categoryNames: categoryNames,
                      money: money,
                    );

                    final monthChipLabel = _monthShortNames[now.month - 1];

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fmtRange(rangeStart, rangeEnd),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _WindowChip(
                                label: 'This month',
                                selected:
                                    rangeMode == ActualsRangeMode.thisMonth,
                                onTap: () {
                                  ref
                                      .read(actualsRangeModeProvider.notifier)
                                      .state = ActualsRangeMode
                                      .thisMonth;
                                },
                              ),
                              const SizedBox(width: 6),
                              _WindowChip(
                                label: 'Last month',
                                selected:
                                    rangeMode == ActualsRangeMode.lastMonth,
                                onTap: () {
                                  ref
                                      .read(actualsRangeModeProvider.notifier)
                                      .state = ActualsRangeMode
                                      .lastMonth;
                                },
                              ),
                              const SizedBox(width: 6),
                              _WindowChip(
                                label: 'Custom',
                                selected: rangeMode == ActualsRangeMode.custom,
                                onTap: () => _pickCustomRange(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryCard(
                                  title: 'Income',
                                  value: money(rangeIncome),
                                  subtitle: showPlan
                                      ? 'Projected ${money(plannedIncome)}'
                                      : null,
                                  icon: Icons.arrow_upward_rounded,
                                  valueColor: colors.successColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _SummaryCard(
                                  title: 'Expenses',
                                  value: money(rangeExpense),
                                  subtitle: showPlan
                                      ? 'Projected ${money(plannedExpense)}'
                                      : null,
                                  icon: Icons.arrow_downward_rounded,
                                  valueColor: colors.dangerColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _SummaryCard(
                                  title: 'Net',
                                  value: money(net),
                                  icon: Icons.swap_vert_rounded,
                                  valueColor: net >= 0
                                      ? colors.successColor
                                      : colors.dangerColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _SectionCard(
                                  title: 'Recent Transactions',
                                  child: recentTop.isEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 20,
                                          ),
                                          child: Text(
                                            'No transactions yet',
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        )
                                      : Column(
                                          children: recentTop.map((t) {
                                            final isIncome =
                                                t.type ==
                                                TransactionType.income;
                                            final isTransfer =
                                                t.type ==
                                                TransactionType.transfer;
                                            final dateStr =
                                                '${t.date.month.toString().padLeft(2, '0')}/${t.date.day.toString().padLeft(2, '0')}';

                                            final String amountText;
                                            final Color amountColor;
                                            if (isTransfer) {
                                              amountText = money(t.amount);
                                              amountColor = colors.textPrimary;
                                            } else if (isIncome) {
                                              amountText =
                                                  '+${money(t.amount)}';
                                              amountColor = colors.successColor;
                                            } else {
                                              amountText = money(-t.amount);
                                              amountColor = colors.dangerColor;
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 14,
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: 42,
                                                    child: Text(
                                                      dateStr,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: colors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      t.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    amountText,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: amountColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    if (showPlan) ...[
                                      _SectionCard(
                                        title: 'The Plan',
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _InsightLine(
                                              data: _incomeInsight(
                                                rangeIncome,
                                                plannedIncome,
                                                money,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            _InsightLine(
                                              data: _expenseInsight(
                                                rangeExpense,
                                                plannedExpense,
                                                money,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            _InsightLine(
                                              data: _netInsight(
                                                net,
                                                plannedIncome - plannedExpense,
                                                money,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    _SectionCard(
                                      title: 'Insights',
                                      titleTooltip:
                                          'Shows spending patterns from expenses only. '
                                          '“Highest spend” ignores categories with only one transaction '
                                          '(e.g. a single rent payment) so fixed bills don’t dominate.',
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _WindowChip(
                                            label: monthChipLabel,
                                            selected:
                                                _window == _InsightWindow.month,
                                            onTap: () => setState(
                                              () => _window =
                                                  _InsightWindow.month,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          _WindowChip(
                                            label: '14',
                                            selected:
                                                _window ==
                                                _InsightWindow.days14,
                                            onTap: () => setState(
                                              () => _window =
                                                  _InsightWindow.days14,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          _WindowChip(
                                            label: '30',
                                            selected:
                                                _window ==
                                                _InsightWindow.days30,
                                            onTap: () => setState(
                                              () => _window =
                                                  _InsightWindow.days30,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child:
                                          (snapshot.mostOften == null &&
                                              snapshot.highestRepeat == null)
                                          ? Text(
                                              'No expenses in this period',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: colors.textSecondary,
                                              ),
                                            )
                                          : Column(
                                              children: [
                                                if (snapshot.mostOften != null)
                                                  _SnapshotLine(
                                                    label: 'Most often',
                                                    name: snapshot
                                                        .mostOften!
                                                        .name,
                                                    count: snapshot
                                                        .mostOften!
                                                        .count,
                                                    total: money(
                                                      snapshot.mostOften!.total,
                                                    ),
                                                    nameColor: colors.primary,
                                                    itemsTooltip: snapshot
                                                        .mostOften!
                                                        .itemsTooltip,
                                                    lineTooltip: 'Category with the most expense transactions in this period',
                                                  ),
                                                if (snapshot.mostOften !=
                                                        null &&
                                                    snapshot.highestRepeat !=
                                                        null)
                                                  const SizedBox(height: 12),
                                                if (snapshot.highestRepeat !=
                                                    null)
                                                  _SnapshotLine(
                                                    label: 'Highest spend',
                                                    name: snapshot
                                                        .highestRepeat!
                                                        .name,
                                                    count: snapshot
                                                        .highestRepeat!
                                                        .count,
                                                    total: money(
                                                      snapshot
                                                          .highestRepeat!
                                                          .total,
                                                    ),
                                                    nameColor: colors.primary,
                                                    itemsTooltip: snapshot
                                                        .highestRepeat!
                                                        .itemsTooltip,
                                                    lineTooltip: 'Highest total among categories with 2+ expenses (excludes one-off bills)',
                                                  ),
                                              ],
                                            ),
                                    ),
                                    const SizedBox(height: 16),
                                    _SectionCard(
                                      title: 'Accounts',
                                      trailing: Text(
                                        'Net ${money(netWorth)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: netWorth >= 0
                                              ? colors.successColor
                                              : colors.dangerColor,
                                        ),
                                      ),
                                      child: trackedAccounts.isEmpty
                                          ? Text(
                                              'No accounts yet',
                                              style: TextStyle(
                                                color: colors.textSecondary,
                                              ),
                                            )
                                          : Column(
                                              children: trackedAccounts.map((
                                                a,
                                              ) {
                                                final live =
                                                    balances[a.id] ??
                                                    a.startingBalance;
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 12,
                                                      ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(a.name),
                                                      Text(
                                                        money(live),
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: live >= 0
                                                              ? colors
                                                                    .successColor
                                                              : colors
                                                                    .dangerColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  (DateTime, DateTime) _rangeForWindow({
    required _InsightWindow window,
    required DateTime today,
    required DateTime monthStart,
    required DateTime monthEnd,
  }) {
    switch (window) {
      case _InsightWindow.month:
        return (monthStart, monthEnd);
      case _InsightWindow.days14:
        return (today.subtract(const Duration(days: 13)), today);
      case _InsightWindow.days30:
        return (today.subtract(const Duration(days: 29)), today);
    }
  }

  _SpendingSnapshot _spendingSnapshot({
    required List<ActualTransaction> transactions,
    required DateTime start,
    required DateTime end,
    required Map<String, String> categoryNames,
    required String Function(double) money,
  }) {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    final byCategory = <String, _Agg>{};

    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      if (d.isBefore(startDay) || d.isAfter(endDay)) continue;

      final c = byCategory.putIfAbsent(
        t.categoryId,
        () => _Agg(name: categoryNames[t.categoryId] ?? 'Category'),
      );
      c.count += 1;
      c.total += t.amount;
      c.items.add(_ItemSample(name: t.name, amount: t.amount));
    }

    _Agg? mostOften;
    for (final c in byCategory.values) {
      if (mostOften == null ||
          c.count > mostOften.count ||
          (c.count == mostOften.count && c.total > mostOften.total)) {
        mostOften = c;
      }
    }

    _Agg? highestRepeat;
    for (final c in byCategory.values) {
      if (c.count < 2) continue;
      if (highestRepeat == null || c.total > highestRepeat.total) {
        highestRepeat = c;
      }
    }

    if (mostOften != null &&
        highestRepeat != null &&
        mostOften.name == highestRepeat.name &&
        mostOften.count == highestRepeat.count) {
      _Agg? second;
      for (final c in byCategory.values) {
        if (c.count < 2) continue;
        if (c.name == mostOften.name) continue;
        if (second == null || c.total > second.total) second = c;
      }
      highestRepeat = second;
    }

    return _SpendingSnapshot(
      mostOften: mostOften?.withTooltip(money),
      highestRepeat: highestRepeat?.withTooltip(money),
    );
  }
}

class _ItemSample {
  final String name;
  final double amount;
  _ItemSample({required this.name, required this.amount});
}

class _Agg {
  final String name;
  int count = 0;
  double total = 0;
  final List<_ItemSample> items = [];
  String itemsTooltip = '';

  _Agg({required this.name});

  _Agg withTooltip(String Function(double) money) {
    final lines = <String>[];
    for (final item in items) {
      final short = item.name.length <= 10
          ? item.name
          : '${item.name.substring(0, 10)}…';
      lines.add('$short  ${money(item.amount)}');
    }
    itemsTooltip = lines.isEmpty ? 'No items' : lines.join('\n');
    return this;
  }
}

class _SpendingSnapshot {
  final _Agg? mostOften;
  final _Agg? highestRepeat;
  _SpendingSnapshot({this.mostOften, this.highestRepeat});
}

class _WindowChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WindowChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      backgroundColor: colors.surfaceElevated,
      selectedColor: colors.primary.withValues(alpha: isDark ? 0.25 : 0.15),
      checkmarkColor: colors.primary,
      side: BorderSide(
        color: selected
            ? colors.primary.withValues(alpha: isDark ? 0.7 : 0.9)
            : colors.border,
        width: 1,
      ),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

class _SnapshotLine extends StatelessWidget {
  final String label;
  final String name;
  final int count;
  final String total;
  final Color nameColor;
  final String itemsTooltip;
  final String lineTooltip;

  const _SnapshotLine({
    required this.label,
    required this.name,
    required this.count,
    required this.total,
    required this.nameColor,
    required this.itemsTooltip,
    required this.lineTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final muted = colors.textSecondary;

    final tip = [
      lineTooltip,
      if (itemsTooltip.isNotEmpty) '',
      if (itemsTooltip.isNotEmpty) itemsTooltip,
    ].join('\n');

    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: nameColor,
                  ),
                ),
              ),
              Text('$count', style: TextStyle(fontSize: 13, color: muted)),
              const SizedBox(width: 12),
              Text(
                total,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.dangerColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightData {
  final String prefix;
  final String? amount;
  final String suffix;
  final Color? amountColor;

  const _InsightData({
    required this.prefix,
    this.amount,
    required this.suffix,
    this.amountColor,
  });
}

// Top-level helpers use static colors (no BuildContext available)
_InsightData _incomeInsight(
  double actual,
  double planned,
  String Function(double) money,
) {
  if (planned <= 0) {
    return const _InsightData(
      prefix: 'Income — no projected amount',
      suffix: '',
    );
  }
  final d = actual - planned;
  if (d.abs() < 0.5) {
    return const _InsightData(prefix: 'Income on projection', suffix: '');
  }
  if (d > 0) {
    return _InsightData(
      prefix: 'Income ',
      amount: '${money(d)} ',
      suffix: 'over projected',
      amountColor: AppColors.success,
    );
  }
  return _InsightData(
    prefix: 'Income ',
    amount: '${money(d.abs())} ',
    suffix: 'under projected',
    amountColor: AppColors.danger,
  );
}

_InsightData _expenseInsight(
  double actual,
  double planned,
  String Function(double) money,
) {
  if (planned <= 0) {
    return const _InsightData(
      prefix: 'Expenses — no projected amount',
      suffix: '',
    );
  }
  final d = actual - planned;
  if (d.abs() < 0.5) {
    return const _InsightData(prefix: 'Expenses on projection', suffix: '');
  }
  if (d > 0) {
    return _InsightData(
      prefix: 'Expenses ',
      amount: '${money(d)} ',
      suffix: 'over projected',
      amountColor: AppColors.danger,
    );
  }
  return _InsightData(
    prefix: 'Expenses ',
    amount: '${money(d.abs())} ',
    suffix: 'under projected',
    amountColor: AppColors.success,
  );
}

_InsightData _netInsight(
  double actualNet,
  double plannedNet,
  String Function(double) money,
) {
  final d = actualNet - plannedNet;
  if (d.abs() < 0.5) {
    return const _InsightData(prefix: 'Net on projection', suffix: '');
  }
  if (d > 0) {
    return _InsightData(
      prefix: 'Net ',
      amount: '${money(d)} ',
      suffix: 'over projected',
      amountColor: AppColors.success,
    );
  }
  return _InsightData(
    prefix: 'Net ',
    amount: '${money(d.abs())} ',
    suffix: 'under projected',
    amountColor: AppColors.danger,
  );
}

class _InsightLine extends StatelessWidget {
  final _InsightData data;
  const _InsightLine({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final base = TextStyle(
      fontSize: 13,
      height: 1.35,
      color: colors.textSecondary,
    );
    if (data.amount == null) return Text(data.prefix, style: base);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: data.prefix),
          TextSpan(
            text: data.amount,
            style: base.copyWith(
              color: data.amountColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: data.suffix),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? valueColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? ' ',
            style: TextStyle(
              fontSize: 12,
              color: subtitle == null
                  ? Colors.transparent
                  : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final String? titleTooltip;

  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    this.titleTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    Widget titleWidget = Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );

    if (titleTooltip != null) {
      titleWidget = Tooltip(
        message: titleTooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            titleWidget,
            const SizedBox(width: 6),
            Icon(Icons.info_outline, size: 14, color: colors.textSecondary),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              titleWidget,
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
