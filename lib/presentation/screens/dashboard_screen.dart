import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/projected_transaction.dart';
import '../providers/app_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _fmtShort(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  Future<void> _persistRange(WidgetRef ref, AppSettings settings) async {
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

  Future<void> _pickCustomStart(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final initial =
        ref.read(projectionCustomStartProvider) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    ref.read(projectionLookbackModeProvider.notifier).state =
        ProjectionLookbackMode.custom;
    ref.read(projectionCustomStartProvider.notifier).state =
        DateTime(picked.year, picked.month, picked.day);
    await _persistRange(ref, settings);
  }

  Future<void> _pickCustomEnd(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final initial =
        ref.read(projectionCustomEndProvider) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    ref.read(projectionHorizonModeProvider.notifier).state =
        ProjectionHorizonMode.custom;
    ref.read(projectionCustomEndProvider.notifier).state =
        DateTime(picked.year, picked.month, picked.day);
    await _persistRange(ref, settings);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    ref.watch(projectionRangeBootstrapProvider);
    final occurrencesAsync = ref.watch(projectionOccurrencesProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final paidIdsAsync = ref.watch(paidOccurrenceIdsProvider);
    final range = ref.watch(projectionRangeProvider);
    final lookbackMode = ref.watch(projectionLookbackModeProvider);
    final horizonMode = ref.watch(projectionHorizonModeProvider);
    final canLastPay = ref.watch(canUseLastPayProvider);
    final canNextPay = ref.watch(canUseNextPayProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final skippedIds =
        ref.watch(skippedOccurrenceIdsProvider).valueOrNull ?? <String>{};

    final categoryNames = <String, String>{
      for (final c in categoriesAsync.valueOrNull ?? []) c.id: c.name,
    };

    return occurrencesAsync.when(
      data: (occurrences) {
        return paidIdsAsync.when(
          data: (paidIds) {
            return settingsAsync.when(
              data: (settings) {
                String money(double v) =>
                    formatMoneyFromSettings(v, settings);
                final today = DateTime.now();
                final todayDate =
                    DateTime(today.year, today.month, today.day);

                double projectedIncome = 0;
                double projectedExpense = 0;
                double unpaidExpense = 0;

                for (final occ in occurrences) {
                  if (skippedIds.contains(occ.id)) continue;

                  final isPaid = paidIds.contains(occ.id);

                  if (occ.type == TransactionType.income) {
                    projectedIncome += occ.amount;
                  } else {
                    projectedExpense += occ.amount;
                    if (!isPaid) {
                      unpaidExpense += occ.amount;
                    }
                  }
                }

                final starting = settings.startingBalance;
                final safety = settings.safetyBuffer;

                double projectedBalance = starting;
                for (final occ in occurrences) {
                  if (paidIds.contains(occ.id) ||
                      skippedIds.contains(occ.id)) {
                    continue;
                  }
                  if (occ.type == TransactionType.income) {
                    projectedBalance += occ.amount;
                  } else {
                    projectedBalance -= occ.amount;
                  }
                }

                final safeToSpend = projectedBalance - safety;
                final upcoming = occurrences
                    .where((o) =>
                        o.type == TransactionType.expense &&
                        !paidIds.contains(o.id) &&
                        !skippedIds.contains(o.id))
                    .toList()
                  ..sort((a, b) => a.date.compareTo(b.date));

                final upcomingPreview = upcoming.take(10).toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'From',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _RangeChip(
                                  label: '1st',
                                  tooltip: 'Start of this month',
                                  selected: lookbackMode ==
                                      ProjectionLookbackMode.monthStart,
                                  onTap: () async {
                                    ref
                                        .read(
                                            projectionLookbackModeProvider
                                                .notifier)
                                        .state =
                                        ProjectionLookbackMode.monthStart;
                                    await _persistRange(ref, settings);
                                  },
                                ),
                                const SizedBox(width: 6),
                                _RangeChip(
                                  label: '\$←',
                                  tooltip: canLastPay
                                      ? 'Since last projected income'
                                      : 'Add projected income to use this',
                                  selected: lookbackMode ==
                                      ProjectionLookbackMode.lastPay,
                                  enabled: canLastPay,
                                  onTap: canLastPay
                                      ? () async {
                                          ref
                                              .read(
                                                  projectionLookbackModeProvider
                                                      .notifier)
                                              .state =
                                              ProjectionLookbackMode
                                                  .lastPay;
                                          await _persistRange(
                                              ref, settings);
                                        }
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                _RangeChip(
                                  icon: Icons.calendar_today,
                                  tooltip: 'Custom start date',
                                  selected: lookbackMode ==
                                      ProjectionLookbackMode.custom,
                                  onTap: () => _pickCustomStart(
                                      context, ref, settings),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'To',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _RangeChip(
                                  label: 'EOM',
                                  tooltip: 'End of this month',
                                  selected: horizonMode ==
                                      ProjectionHorizonMode.eom,
                                  onTap: () async {
                                    ref
                                        .read(
                                            projectionHorizonModeProvider
                                                .notifier)
                                        .state =
                                        ProjectionHorizonMode.eom;
                                    await _persistRange(ref, settings);
                                  },
                                ),
                                const SizedBox(width: 6),
                                _RangeChip(
                                  label: '→\$',
                                  tooltip: canNextPay
                                      ? 'Until next pay (day before next income)'
                                      : 'Add projected income to use this',
                                  selected: horizonMode ==
                                      ProjectionHorizonMode.nextPay,
                                  enabled: canNextPay,
                                  onTap: canNextPay
                                      ? () async {
                                          ref
                                              .read(
                                                  projectionHorizonModeProvider
                                                      .notifier)
                                              .state =
                                              ProjectionHorizonMode
                                                  .nextPay;
                                          await _persistRange(
                                              ref, settings);
                                        }
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                _RangeChip(
                                  icon: Icons.calendar_today,
                                  tooltip: 'Custom end date',
                                  selected: horizonMode ==
                                      ProjectionHorizonMode.custom,
                                  onTap: () => _pickCustomEnd(
                                      context, ref, settings),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_fmt(range.start)}  →  ${_fmt(range.end)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: 'Projected Income',
                              value: money(projectedIncome),
                              icon: Icons.arrow_upward_rounded,
                              valueColor: colors.successColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Projected Expenses',
                              value: money(projectedExpense),
                              icon: Icons.arrow_downward_rounded,
                              valueColor: colors.dangerColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Unpaid Expenses',
                              value: money(unpaidExpense),
                              icon: Icons.pending_actions_rounded,
                              valueColor: colors.warningColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Safe to Spend',
                              value: money(safeToSpend),
                              icon: Icons.savings_rounded,
                              valueColor: safeToSpend >= 0
                                  ? colors.cyan
                                  : colors.dangerColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Balance Overview',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _BalanceTile(
                                    label: 'Current balance',
                                    value: money(starting),
                                    color: starting >= 0
                                        ? colors.successColor
                                        : colors.dangerColor,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 48,
                                  color: colors.border,
                                ),
                                Expanded(
                                  child: _BalanceTile(
                                    label: 'Projected balance',
                                    value: money(projectedBalance),
                                    color: projectedBalance >= 0
                                        ? colors.primary
                                        : colors.dangerColor,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 48,
                                  color: colors.border,
                                ),
                                Expanded(
                                  child: _BalanceTile(
                                    label: 'Safety buffer',
                                    value: money(safety),
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colors.border),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Upcoming Expenses',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (upcoming.isNotEmpty)
                                        Text(
                                          upcoming.length > 10
                                              ? 'Next 10 of ${upcoming.length}'
                                              : '${upcoming.length} unpaid',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (upcomingPreview.isEmpty)
                                    Text(
                                      'No unpaid expenses in this range.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.textSecondary,
                                      ),
                                    )
                                  else
                                    ...upcomingPreview
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final i = entry.key;
                                      final occ = entry.value;
                                      final occDate = DateTime(
                                        occ.date.year,
                                        occ.date.month,
                                        occ.date.day,
                                      );
                                      final overdue =
                                          occDate.isBefore(todayDate);
                                      final cat =
                                          categoryNames[occ.categoryId] ??
                                              'Unknown';

                                      return Column(
                                        children: [
                                          Padding(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 8),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 52,
                                                  child: Text(
                                                    _fmtShort(occ.date),
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: overdue
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                      color: overdue
                                                          ? const Color(
                                                              0xFFF97316)
                                                          : colors
                                                              .textSecondary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        occ.name,
                                                        style:
                                                            const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w500,
                                                        ),
                                                      ),
                                                      Text(
                                                        cat,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: colors
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  money(-occ.amount),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color:
                                                        colors.dangerColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (i <
                                              upcomingPreview.length - 1)
                                            Divider(
                                              height: 1,
                                              thickness: 1,
                                              color: colors.border
                                                  .withValues(alpha: 0.5),
                                            ),
                                        ],
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Totals use this range, paid, and skipped from the Projection timeline.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
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
          loading: () =>
              const Center(child: CircularProgressIndicator()),
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

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected && enabled ? colors.primary : colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected && enabled ? colors.primary : colors.border,
          width: 1,
        ),
      ),
      child: icon != null
          ? Icon(
              icon,
              size: 16,
              color: !enabled
                  ? colors.textSecondary.withValues(alpha: 0.35)
                  : selected
                      ? Colors.white
                      : colors.textSecondary,
            )
          : Text(
              label ?? '',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: !enabled
                    ? colors.textSecondary.withValues(alpha: 0.35)
                    : selected
                        ? Colors.white
                        : colors.textSecondary,
              ),
            ),
    );

    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: child,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _SummaryCard({
    required this.title,
    required this.value,
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
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
            ),
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
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BalanceTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}