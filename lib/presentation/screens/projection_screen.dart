import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/projected_transaction.dart';
import '../../domain/services/projection_service.dart';
import '../providers/app_providers.dart';

class ProjectionScreen extends ConsumerStatefulWidget {
  const ProjectionScreen({super.key});

  @override
  ConsumerState<ProjectionScreen> createState() => _ProjectionScreenState();
}

class _ProjectionScreenState extends ConsumerState<ProjectionScreen> {
  String? _selectedCategoryId;

  Future<void> _persistRange(AppSettings settings) async {
    if (!settings.rememberProjectionRange) return;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.updateSettings(
      settings.copyWith(
        lookbackMode: ref.read(projectionLookbackModeProvider),
        horizonMode: ref.read(projectionHorizonModeProvider),
        customLookbackStart: ref.read(projectionCustomStartProvider),
        customHorizonEnd: ref.read(projectionCustomEndProvider),
      ),
    );
    ref.invalidate(settingsProvider);
  }

  Future<void> _editStartingBalance(AppSettings settings) async {
    final controller = TextEditingController(
      text: settings.startingBalance.toStringAsFixed(2),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Starting Balance'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final v = double.tryParse(controller.text.trim());
                if (v != null) Navigator.pop(ctx, v);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.updateSettings(settings.copyWith(startingBalance: result));
    ref.invalidate(settingsProvider);
  }

  Future<void> _pickCustomStart(AppSettings settings) async {
    final initial = ref.read(projectionCustomStartProvider) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    ref.read(projectionLookbackModeProvider.notifier).state =
        ProjectionLookbackMode.custom;
    ref.read(projectionCustomStartProvider.notifier).state = DateTime(
      picked.year,
      picked.month,
      picked.day,
    );
    await _persistRange(settings);
  }

  Future<void> _pickCustomEnd(AppSettings settings) async {
    final initial = ref.read(projectionCustomEndProvider) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    ref.read(projectionHorizonModeProvider.notifier).state =
        ProjectionHorizonMode.custom;
    ref.read(projectionCustomEndProvider.notifier).state = DateTime(
      picked.year,
      picked.month,
      picked.day,
    );
    await _persistRange(settings);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.watch(projectionRangeBootstrapProvider);
    final occurrencesAsync = ref.watch(projectionOccurrencesProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final paidIdsAsync = ref.watch(paidOccurrenceIdsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final skippedIds =
        ref.watch(skippedOccurrenceIdsProvider).valueOrNull ?? <String>{};
    final range = ref.watch(projectionRangeProvider);
    final lookbackMode = ref.watch(projectionLookbackModeProvider);
    final horizonMode = ref.watch(projectionHorizonModeProvider);
    final canLastPay = ref.watch(canUseLastPayProvider);
    final canNextPay = ref.watch(canUseNextPayProvider);

    final categoryNames = <String, String>{
      for (final c in categoriesAsync.valueOrNull ?? []) c.id: c.name,
    };

    return occurrencesAsync.when(
      data: (occurrences) {
        return paidIdsAsync.when(
          data: (paidIds) {
            return settingsAsync.when(
              data: (settings) {
                String money(double v) => formatMoneyFromSettings(v, settings);

                final effective = occurrences.map((occ) {
                  return ProjectionOccurrence(
                    id: occ.id,
                    templateId: occ.templateId,
                    name: occ.name,
                    amount: occ.amount,
                    type: occ.type,
                    categoryId: occ.categoryId,
                    date: occ.date,
                    isPaid: paidIds.contains(occ.id),
                    recurrence: occ.recurrence,
                  );
                }).toList();

                double balance = settings.startingBalance;
                double totalIncome = 0;
                double totalExpense = 0;
                final List<double> balancesForChart = [
                  settings.startingBalance,
                ];
                final List<double> runningBalances = [];

                for (final occ in effective) {
                  final skipped = skippedIds.contains(occ.id);
                  if (!occ.isPaid && !skipped) {
                    if (occ.type == TransactionType.income) {
                      balance += occ.amount;
                      totalIncome += occ.amount;
                    } else {
                      balance -= occ.amount;
                      totalExpense += occ.amount;
                    }
                  }
                  runningBalances.add(balance);
                  balancesForChart.add(balance);
                }
                final safeToSpend = balance - settings.safetyBuffer;
                final netUnpaid = totalIncome - totalExpense;

                final paidFilter = settings.projectionPaidFilter;

                final visibleIndexes = <int>[
                  for (int i = 0; i < effective.length; i++)
                    if ((_selectedCategoryId == null ||
                            effective[i].categoryId == _selectedCategoryId) &&
                        switch (paidFilter) {
                          ProjectionPaidFilter.all => true,
                          ProjectionPaidFilter.unpaid => !effective[i].isPaid,
                          ProjectionPaidFilter.paid => effective[i].isPaid,
                        })
                      i,
                ];
                return Column(
                  children: [
                    // Summary cards
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 8, 32, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: 'Starting Balance',
                              value: money(settings.startingBalance),
                              editable: true,
                              onTap: () => _editStartingBalance(settings),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Projected Balance',
                              value: money(balance),
                              color: balance >= 0
                                  ? colors.successColor
                                  : colors.dangerColor,
                              tooltip: 'Starting balance after unpaid items in this range (paid and skipped ignored).',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Safe to Spend',
                              value: money(safeToSpend),
                              color: safeToSpend >= 0
                                  ? colors.cyan
                                  : colors.dangerColor,
                              tooltip:
                                  'Projected balance minus your safety buffer.',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Remaining',
                              value: money(netUnpaid),
                              color: netUnpaid >= 0
                                  ? colors.successColor
                                  : colors.dangerColor,
                              tooltip: 'Events still to happen in this range (skipped ignored).',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // From / To chips
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 10),
                      child: Row(
                        children: [
                          Text(
                            'From',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _RangeChip(
                            label: '1st',
                            tooltip: 'Start of this month',
                            selected:
                                lookbackMode ==
                                ProjectionLookbackMode.monthStart,
                            onTap: () async {
                              ref
                                  .read(projectionLookbackModeProvider.notifier)
                                  .state = ProjectionLookbackMode
                                  .monthStart;
                              await _persistRange(settings);
                            },
                          ),
                          const SizedBox(width: 6),
                          _RangeChip(
                            label: '\$←',
                            tooltip: canLastPay
                                ? 'Since last projected income'
                                : 'Add projected income to use this',
                            selected:
                                lookbackMode == ProjectionLookbackMode.lastPay,
                            enabled: canLastPay,
                            onTap: canLastPay
                                ? () async {
                                    ref
                                            .read(
                                              projectionLookbackModeProvider
                                                  .notifier,
                                            )
                                            .state =
                                        ProjectionLookbackMode.lastPay;
                                    await _persistRange(settings);
                                  }
                                : null,
                          ),
                          const SizedBox(width: 6),
                          _RangeChip(
                            icon: Icons.calendar_today,
                            tooltip: 'Custom start date',
                            selected:
                                lookbackMode == ProjectionLookbackMode.custom,
                            onTap: () => _pickCustomStart(settings),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'To',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _RangeChip(
                            label: 'EOM',
                            tooltip: 'End of this month',
                            selected: horizonMode == ProjectionHorizonMode.eom,
                            onTap: () async {
                              ref
                                  .read(projectionHorizonModeProvider.notifier)
                                  .state = ProjectionHorizonMode
                                  .eom;
                              await _persistRange(settings);
                            },
                          ),
                          const SizedBox(width: 6),
                          _RangeChip(
                            label: '→\$',
                            tooltip: canNextPay
                                ? 'Until next pay (day before next income)'
                                : 'Add projected income to use this',
                            selected:
                                horizonMode == ProjectionHorizonMode.nextPay,
                            enabled: canNextPay,
                            onTap: canNextPay
                                ? () async {
                                    ref
                                            .read(
                                              projectionHorizonModeProvider
                                                  .notifier,
                                            )
                                            .state =
                                        ProjectionHorizonMode.nextPay;
                                    await _persistRange(settings);
                                  }
                                : null,
                          ),
                          const SizedBox(width: 6),
                          _RangeChip(
                            icon: Icons.calendar_today,
                            tooltip: 'Custom end date',
                            selected:
                                horizonMode == ProjectionHorizonMode.custom,
                            onTap: () => _pickCustomEnd(settings),
                          ),
                          if (_selectedCategoryId != null) ...[
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedCategoryId = null),
                              icon: const Icon(Icons.filter_alt_off, size: 18),
                              label: Text(
                                categoryNames[_selectedCategoryId] ?? 'Clear',
                              ),
                            ),
                          ],
                          const Spacer(),
                          Tooltip(
                            message: switch (settings.projectionPaidFilter) {
                              ProjectionPaidFilter.all =>
                                'Showing all · tap for Unpaid',
                              ProjectionPaidFilter.unpaid =>
                                'Showing unpaid · tap for Paid',
                              ProjectionPaidFilter.paid =>
                                'Showing paid · tap for All',
                            },
                            child: Material(
                              color: isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightSurface,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  final next =
                                      switch (settings.projectionPaidFilter) {
                                        ProjectionPaidFilter.all =>
                                          ProjectionPaidFilter.unpaid,
                                        ProjectionPaidFilter.unpaid =>
                                          ProjectionPaidFilter.paid,
                                        ProjectionPaidFilter.paid =>
                                          ProjectionPaidFilter.all,
                                      };
                                  await ref
                                      .read(settingsRepositoryProvider)
                                      .updateSettings(
                                        settings.copyWith(
                                          projectionPaidFilter: next,
                                        ),
                                      );
                                  ref.invalidate(settingsProvider);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        switch (settings.projectionPaidFilter) {
                                          ProjectionPaidFilter.all => 'All',
                                          ProjectionPaidFilter.unpaid =>
                                            'Unpaid',
                                          ProjectionPaidFilter.paid => 'Paid',
                                        },
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.sync_rounded,
                                        size: 14,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_fmt(range.start)}  →  ${_fmt(range.end)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface.withValues(alpha: 0.5)
                              : AppColors.lightSurface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                'Date',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Description',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(
                                'Category',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(
                                'Amount',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            SizedBox(width: 24),
                            SizedBox(
                              width: 110,
                              child: Text(
                                'Balance',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            SizedBox(width: 24),
                            SizedBox(
                              width: 70,
                              child: Text(
                                'Paid',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Expanded(
                      child: effective.isEmpty
                          ? Center(
                              child: Text(
                                'No projected occurrences in this range.\nAdd some incomes or expenses first.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            )
                          : visibleIndexes.isEmpty
                          ? Center(
                              child: Text(
                                'No occurrences in this category',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                              itemCount: visibleIndexes.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, listIndex) {
                                final index = visibleIndexes[listIndex];
                                final occ = effective[index];
                                final bal = runningBalances[index];
                                final isIncome =
                                    occ.type == TransactionType.income;

                                return _OccurrenceRow(
                                  occurrence: occ,
                                  runningBalance: bal,
                                  isIncome: isIncome,
                                  money: money,
                                  categoryName:
                                      categoryNames[occ.categoryId] ??
                                      'Unknown',
                                  selectedCategoryId: _selectedCategoryId,
                                  onCategoryTap: (id) {
                                    setState(() {
                                      _selectedCategoryId =
                                          _selectedCategoryId == id ? null : id;
                                    });
                                  },
                                  onPaidChanged: (value) async {
                                    final repo = ref.read(
                                      paidOccurrenceRepositoryProvider,
                                    );
                                    if (value) {
                                      await repo.markPaid(
                                        occurrenceId: occ.id,
                                        templateId: occ.templateId,
                                        date: occ.date,
                                      );
                                    } else {
                                      await repo.markUnpaid(occ.id);
                                    }
                                    ref.invalidate(paidOccurrenceIdsProvider);
                                  },
                                  isSkipped: skippedIds.contains(occ.id),
                                  onSkipToggle: () async {
                                    final repo = ref.read(
                                      skippedOccurrenceRepositoryProvider,
                                    );
                                    if (skippedIds.contains(occ.id)) {
                                      await repo.markUnskipped(occ.id);
                                    } else {
                                      await repo.markSkipped(
                                        occurrenceId: occ.id,
                                        templateId: occ.templateId,
                                        date: occ.date,
                                      );
                                    }
                                    ref.invalidate(
                                      skippedOccurrenceIdsProvider,
                                    );
                                  },
                                );
                              },
                            ),
                    ),

                    if (balancesForChart.length > 1)
                      Container(
                        height: 90,
                        margin: const EdgeInsets.fromLTRB(32, 12, 32, 8),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Running Balance',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) {
                                      return FlLine(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.05,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                        strokeWidth: 1,
                                      );
                                    },
                                  ),
                                  titlesData: const FlTitlesData(show: false),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: [
                                        for (
                                          int i = 0;
                                          i < balancesForChart.length;
                                          i++
                                        )
                                          FlSpot(
                                            i.toDouble(),
                                            balancesForChart[i],
                                          ),
                                      ],
                                      isCurved: true,
                                      color: colors.primary,
                                      barWidth: 2.5,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: colors.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                  ],
                                  minY:
                                      balancesForChart.reduce(
                                        (a, b) => a < b ? a : b,
                                      ) *
                                      0.97,
                                  maxY:
                                      balancesForChart.reduce(
                                        (a, b) => a > b ? a : b,
                                      ) *
                                      1.03,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
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
}

class _RangeChip extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String tooltip;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _RangeChip({
    this.label,
    this.icon,
    required this.tooltip,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected && enabled
            ? colors.primary
            : (isDark ? Colors.transparent : AppColors.lightSurfaceElevated),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected && enabled
              ? colors.primary
              : (isDark ? const Color(0xFF3A3F4B) : const Color(0xFFB8BFC9)),
          width: 1,
        ),
      ),
      child: icon != null
          ? Icon(
              icon,
              size: 16,
              color: !enabled
                  ? (isDark
                        ? AppColors.textSecondaryDark.withValues(alpha: 0.35)
                        : AppColors.textSecondaryLight.withValues(alpha: 0.35))
                  : selected
                  ? Colors.white
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            )
          : Text(
              label ?? '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: !enabled
                    ? (isDark
                          ? AppColors.textSecondaryDark.withValues(alpha: 0.35)
                          : AppColors.textSecondaryLight.withValues(
                              alpha: 0.35,
                            ))
                    : selected
                    ? Colors.white
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
              ),
            ),
    );

    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GestureDetector(onTap: enabled ? onTap : null, child: child),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color? color;
  final bool editable;
  final VoidCallback? onTap;
  final String? tooltip;

  const _SummaryCard({
    required this.title,
    required this.value,
    this.color,
    this.editable = false,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              if (editable)
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (editable) {
      return Tooltip(
        message: 'Tap to edit',
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: card,
          ),
        ),
      );
    }

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: card,
      );
    }

    return card;
  }
}

class _OccurrenceRow extends StatelessWidget {
  final ProjectionOccurrence occurrence;
  final double runningBalance;
  final bool isIncome;
  final String Function(double) money;
  final String categoryName;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategoryTap;
  final ValueChanged<bool> onPaidChanged;
  final bool isSkipped;
  final VoidCallback onSkipToggle;

  const _OccurrenceRow({
    required this.occurrence,
    required this.runningBalance,
    required this.isIncome,
    required this.money,
    required this.categoryName,
    required this.selectedCategoryId,
    required this.onCategoryTap,
    required this.onPaidChanged,
    required this.isSkipped,
    required this.onSkipToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final occDate = DateTime(
      occurrence.date.year,
      occurrence.date.month,
      occurrence.date.day,
    );

    final isOverdue =
        !isSkipped && !occurrence.isPaid && occDate.isBefore(todayDate);
    final daysOverdue = isOverdue ? todayDate.difference(occDate).inDays : 0;
    final isStrongOverdue = daysOverdue >= 7;

    final overdueColor = isStrongOverdue
        ? (isDark
              ? const Color(0xFFF97316) // way overdue dark mode
              : const Color(0xFFEA580C)) // way overdue light mode
        : (isDark
              ? const Color(0xFFFBBF24) // dark mode recent
              : const Color(0xFFBD9204)); // light mode recent

    final dateStr =
        '${occurrence.date.year}-${occurrence.date.month.toString().padLeft(2, '0')}-${occurrence.date.day.toString().padLeft(2, '0')}';

    final categorySelected = selectedCategoryId == occurrence.categoryId;

    return Opacity(
      opacity: isSkipped ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                dateStr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w500,
                  color: isOverdue
                      ? overdueColor
                      : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    occurrence.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: occurrence.isPaid || isSkipped
                          ? TextDecoration.lineThrough
                          : null,
                      color: occurrence.isPaid || isSkipped
                          ? (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight)
                          : null,
                    ),
                  ),
                  if (isSkipped) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colors.cyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Skipped',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.cyan,
                        ),
                      ),
                    ),
                  ] else if (isOverdue) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: overdueColor.withValues(
                          alpha: isDark ? 0.22 : 0.16,
                        ), // soft wash
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: overdueColor.withValues(
                            alpha: isDark ? 0.7 : 0.9,
                          ), // optional edge
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Overdue',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: overdueColor, // solid label
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 110,
              child: InkWell(
                onTap: () => onCategoryTap(occurrence.categoryId),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 2,
                  ),
                  child: Text(
                    categoryName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: categorySelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                isIncome
                    ? '+${money(occurrence.amount)}'
                    : money(-occurrence.amount),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isIncome ? colors.successColor : colors.dangerColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 110,
              child: Text(
                money(runningBalance),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: runningBalance >= 0
                      ? colors.successColor
                      : colors.dangerColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: occurrence.isPaid
                  ? 'Cannot skip a paid occurrence'
                  : (isSkipped ? 'Unskip' : 'Skip this occurrence'),
              icon: Icon(
                isSkipped ? Icons.undo_rounded : Icons.event_busy_rounded,
                size: 20,
                color: occurrence.isPaid
                    ? (isDark
                          ? AppColors.textSecondaryDark.withValues(alpha: 0.35)
                          : AppColors.textSecondaryLight.withValues(
                              alpha: 0.35,
                            ))
                    : (isSkipped
                          ? colors.cyan
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight)),
              ),
              onPressed: occurrence.isPaid ? null : onSkipToggle,
            ),
            SizedBox(
              width: 70,
              child: Center(
                child: Switch(
                  value: occurrence.isPaid,
                  activeThumbColor: Colors.white,
                  activeTrackColor: colors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                  onChanged: isSkipped ? null : onPaidChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
