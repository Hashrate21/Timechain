import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/account_icons.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/snackbars.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/actual_transaction.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/projected_transaction.dart';
import '../providers/app_providers.dart';
import '../widgets/add_account_dialog.dart';

enum _BalanceChartRange { d30, d90, ytd, all }

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  _BalanceChartRange _chartRange = _BalanceChartRange.d90;
  bool _externalsExpanded = true;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accountsAsync = ref.watch(accountsProvider);
    final balancesAsync = ref.watch(accountBalancesProvider);
    final txAsync = ref.watch(actualTransactionsProvider);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    String money(double v) => formatMoneyFromSettings(v, settings);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 12),
          child: Row(
            children: [
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => const AddAccountDialog(),
                  );
                  ref.invalidate(accountsProvider);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: accountsAsync.when(
            data: (accounts) {
              final tracked = accounts
                  .where((a) => !a.isUntracked && a.isActive)
                  .toList();
              final externals =
                  accounts.where((a) => a.isUntracked && a.isActive).toList()
                    ..sort(
                      (a, b) =>
                          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                    );

              return balancesAsync.when(
                data: (balances) {
                  return txAsync.when(
                    data: (transactions) {
                      final bounds = _rangeBounds(_chartRange);

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        children: [
                          if (tracked.isNotEmpty) ...[
                            Row(
                              children: [
                                Text(
                                  'Balance history',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                _RangeChip(
                                  label: '30d',
                                  selected:
                                      _chartRange == _BalanceChartRange.d30,
                                  onTap: () => setState(
                                    () => _chartRange = _BalanceChartRange.d30,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _RangeChip(
                                  label: '90d',
                                  selected:
                                      _chartRange == _BalanceChartRange.d90,
                                  onTap: () => setState(
                                    () => _chartRange = _BalanceChartRange.d90,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _RangeChip(
                                  label: 'YTD',
                                  selected:
                                      _chartRange == _BalanceChartRange.ytd,
                                  onTap: () => setState(
                                    () => _chartRange = _BalanceChartRange.ytd,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _RangeChip(
                                  label: 'All',
                                  selected:
                                      _chartRange == _BalanceChartRange.all,
                                  onTap: () => setState(
                                    () => _chartRange = _BalanceChartRange.all,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Each chart uses that account’s own scale',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            for (final account in tracked) ...[
                              _AccountCard(
                                account: account,
                                liveBalance:
                                    balances[account.id] ??
                                    account.startingBalance,
                                series: _buildSeries(
                                  account: account,
                                  transactions: transactions,
                                  rangeStart: bounds.$1,
                                  rangeEnd: bounds.$2,
                                ),
                                money: money,
                              ),
                              const SizedBox(height: 12),
                            ],
                            const SizedBox(height: 12),
                          ] else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.account_balance_rounded,
                                      size: 48,
                                      color: colors.textSecondary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No tracked accounts yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // —— External accounts ——
                          _ExternalAccountsSection(
                            externals: externals,
                            expanded: _externalsExpanded,
                            onToggleExpanded: () => setState(
                              () => _externalsExpanded = !_externalsExpanded,
                            ),
                            onAdd: () async {
                              await showDialog(
                                context: context,
                                builder: (context) => const AddAccountDialog(
                                  initialType: AccountType.untracked,
                                ),
                              );
                              ref.invalidate(accountsProvider);
                            },
                            onEdit: (account) async {
                              await showDialog(
                                context: context,
                                builder: (context) =>
                                    AddAccountDialog(existing: account),
                              );
                              ref.invalidate(accountsProvider);
                            },
                            onArchive: (account) async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text(
                                    'Archive external account?',
                                  ),
                                  content: Text(
                                    '"${account.name}" will be hidden from transfer pickers. '
                                    'Past transfers stay in history.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Archive'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              try {
                                await ref
                                    .read(accountRepositoryProvider)
                                    .archive(account.id);
                                ref.invalidate(accountsProvider);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Archived "${account.name}"'),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text('$e')));
                              }
                            },
                            onRestore: () => _restoreArchivedExternal(),
                          ),
                        ],
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
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Future<void> _restoreArchivedExternal() async {
    final accounts = ref.read(accountsProvider).valueOrNull ?? <Account>[];
    final archived =
        accounts.where((a) => a.isUntracked && !a.isActive).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    if (archived.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No archived external accounts')),
      );
      return;
    }

    final chosen = await showDialog<Account>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Restore external account'),
          children: [
            for (final a in archived)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, a),
                child: Text(a.name),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (chosen == null) return;

    try {
      await ref.read(accountRepositoryProvider).restore(chosen);
      ref.invalidate(accountsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Restored "${chosen.name}"')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  (DateTime, DateTime) _rangeBounds(_BalanceChartRange r) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    switch (r) {
      case _BalanceChartRange.d30:
        return (end.subtract(const Duration(days: 29)), end);
      case _BalanceChartRange.d90:
        return (end.subtract(const Duration(days: 89)), end);
      case _BalanceChartRange.ytd:
        return (DateTime(now.year, 1, 1), end);
      case _BalanceChartRange.all:
        return (DateTime(2000, 1, 1), end);
    }
  }

  _AccountSeries _buildSeries({
    required Account account,
    required List<ActualTransaction> transactions,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final start = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final end = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    final txs = transactions.where((t) => t.accountId == account.id).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double balance = account.startingBalance;
    final points = <_BalPoint>[];

    for (final t in txs) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      if (d.isBefore(start)) {
        balance = _apply(balance, t);
      }
    }

    points.add(_BalPoint(day: start, balance: balance));

    for (final t in txs) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      if (d.isBefore(start) || d.isAfter(end)) continue;
      balance = _apply(balance, t);
      points.add(_BalPoint(day: d, balance: balance));
    }

    if (points.isNotEmpty && points.last.day.isBefore(end)) {
      points.add(_BalPoint(day: end, balance: balance));
    }

    return _AccountSeries(
      id: account.id,
      name: account.name,
      color: AccountIcons.colorFor(account.type),
      points: points,
    );
  }

  double _apply(double balance, ActualTransaction t) {
    switch (t.type) {
      case TransactionType.income:
        return balance + t.amount;
      case TransactionType.expense:
        return balance - t.amount;
      case TransactionType.transfer:
        return balance + t.amount;
    }
  }
}

class _ExternalAccountsSection extends StatelessWidget {
  final List<Account> externals;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onAdd;
  final ValueChanged<Account> onEdit;
  final ValueChanged<Account> onArchive;
  final VoidCallback onRestore;

  const _ExternalAccountsSection({
    required this.externals,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onAdd,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: onToggleExpanded,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      expanded
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      size: 22,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      expanded
                          ? 'External accounts'
                          : 'External accounts (${externals.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            TextButton(onPressed: onRestore, child: const Text('Restore')),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        if (expanded) ...[
          const SizedBox(height: 4),
          Text(
            'Transfers only · not in net worth',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (externals.isEmpty)
            Text(
              'No external accounts yet. Add one for transfers to brokerage, kids’ accounts, etc.',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final a in externals)
                  _ExternalChip(
                    account: a,
                    onEdit: () => onEdit(a),
                    onArchive: () => onArchive(a),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

class _ExternalChip extends StatelessWidget {
  final Account account;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _ExternalChip({
    required this.account,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final iconColor = AccountIcons.colorFor(AccountType.untracked);

    return Container(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AccountIcons.data(account.iconKey), size: 18, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            iconSize: 18,
            icon: Icon(Icons.more_vert, size: 18, color: colors.textSecondary),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'archive') onArchive();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'archive', child: Text('Archive')),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalPoint {
  final DateTime day;
  final double balance;
  _BalPoint({required this.day, required this.balance});
}

class _AccountSeries {
  final String id;
  final String name;
  final Color color;
  final List<_BalPoint> points;
  _AccountSeries({
    required this.id,
    required this.name,
    required this.color,
    required this.points,
  });
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
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

class _AccountCard extends ConsumerWidget {
  final Account account;
  final double liveBalance;
  final _AccountSeries series;
  final String Function(double) money;

  const _AccountCard({
    required this.account,
    required this.liveBalance,
    required this.series,
    required this.money,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isAsset = account.type == AccountType.asset;
    final iconColor = AccountIcons.colorFor(account.type);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  AccountIcons.data(account.iconKey),
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAsset ? 'Asset' : 'Liability',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(liveBalance),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: liveBalance >= 0
                          ? colors.successColor
                          : colors.dangerColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Start ${money(account.startingBalance)}',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: colors.textSecondary,
                ),
                onSelected: (value) async {
                  final repo = ref.read(accountRepositoryProvider);

                  if (value == 'edit') {
                    await showDialog(
                      context: context,
                      builder: (context) => AddAccountDialog(existing: account),
                    );
                    ref.invalidate(accountsProvider);
                  }
                  if (value == 'delete') {
                    await repo.delete(account.id);
                    ref.invalidate(accountsProvider);

                    showUndoSnackBar(
                      context,
                      message: '"${account.name}" deleted',
                      onUndo: () async {
                        await repo.insert(account);
                        ref.invalidate(accountsProvider);
                      },
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: _MiniBalanceChart(series: series, money: money),
          ),
        ],
      ),
    );
  }
}

class _MiniBalanceChart extends StatelessWidget {
  final _AccountSeries series;
  final String Function(double) money;

  const _MiniBalanceChart({required this.series, required this.money});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final points = series.points;

    if (points.length < 2) {
      return Center(
        child: Text(
          'No movement in this range',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
      );
    }

    final minD = points.first.day;
    final maxD = points.last.day;
    var minY = points.first.balance;
    var maxY = points.first.balance;
    for (final p in points) {
      if (p.balance < minY) minY = p.balance;
      if (p.balance > maxY) maxY = p.balance;
    }
    if ((maxY - minY).abs() < 1) {
      minY -= 50;
      maxY += 50;
    }
    final pad = (maxY - minY) * 0.12;
    minY -= pad;
    maxY += pad;

    final startMs = minD.millisecondsSinceEpoch.toDouble();
    final span = (maxD.millisecondsSinceEpoch - minD.millisecondsSinceEpoch)
        .toDouble()
        .clamp(1.0, double.infinity);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 1,
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((s) {
                return LineTooltipItem(
                  money(s.y),
                  TextStyle(
                    color: series.color,
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
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                final label = value.abs() >= 1000
                    ? '${(value / 1000).toStringAsFixed(0)}k'
                    : value.toInt().toString();
                return Text(
                  label,
                  style: TextStyle(fontSize: 9, color: colors.textSecondary),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 0.5,
              getTitlesWidget: (value, meta) {
                if (value != 0 && value != 1) {
                  return const SizedBox.shrink();
                }
                final ms = startMs + value * span;
                final d = DateTime.fromMillisecondsSinceEpoch(ms.round());
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${d.month}/${d.day}',
                    style: TextStyle(fontSize: 9, color: colors.textSecondary),
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
          LineChartBarData(
            spots: [
              for (final p in points)
                FlSpot(
                  (p.day.millisecondsSinceEpoch - startMs) / span,
                  p.balance,
                ),
            ],
            isCurved: false,
            color: series.color,
            barWidth: 2.2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: series.color.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}
