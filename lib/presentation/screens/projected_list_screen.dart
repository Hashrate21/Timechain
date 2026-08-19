import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/snackbars.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/projected_transaction.dart';
import '../providers/app_providers.dart';
import '../widgets/add_projected_dialog.dart';

bool _isEndedPriorMonth(ProjectedTransaction t, DateTime today) {
  final end = t.recurrenceEnd;
  if (end == null) return false;
  final endMonth = DateTime(end.year, end.month);
  final thisMonth = DateTime(today.year, today.month);
  return endMonth.isBefore(thisMonth);
}

/// Still in the end month, but end day is already past → dim in active list.
bool _isDimmedActiveEnded(ProjectedTransaction t, DateTime today) {
  final end = t.recurrenceEnd;
  if (end == null) return false;
  if (_isEndedPriorMonth(t, today)) return false;
  final endDay = DateTime(end.year, end.month, end.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  return !endDay.isAfter(todayDay);
}

class ProjectedListScreen extends ConsumerStatefulWidget {
  final TransactionType type;

  const ProjectedListScreen({super.key, required this.type});

  @override
  ConsumerState<ProjectedListScreen> createState() =>
      _ProjectedListScreenState();
}

class _ProjectedListScreenState extends ConsumerState<ProjectedListScreen> {
  String _query = '';
  String? _selectedCategoryId;
  bool _showEnded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = widget.type == TransactionType.income;
    final today = DateTime.now();

    final transactionsAsync = isIncome
        ? ref.watch(projectedIncomesProvider)
        : ref.watch(projectedExpensesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    final categoryNames = <String, String>{
      for (final c in categoriesAsync.valueOrNull ?? []) c.id: c.name,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: TextField(
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              if (_selectedCategoryId != null) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedCategoryId = null),
                  icon: const Icon(Icons.filter_alt_off, size: 18),
                  label: const Text('Clear filter'),
                ),
              ],
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Show ended'),
                selected: _showEnded,
                onSelected: (v) => setState(() => _showEnded = v),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                backgroundColor: colors.surfaceElevated,
                selectedColor: colors.primary.withValues(
                  alpha: isDark ? 0.25 : 0.15,
                ),
                checkmarkColor: colors.primary,
                side: BorderSide(
                  color: _showEnded
                      ? colors.primary.withValues(alpha: isDark ? 0.7 : 0.9)
                      : colors.border,
                  width: 1,
                ),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: _showEnded ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AddProjectedDialog(type: widget.type),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(isIncome ? 'Add Income' : 'Add Expense'),
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
          child: transactionsAsync.when(
            data: (transactions) {
              var filtered = _query.isEmpty
                  ? List<ProjectedTransaction>.from(transactions)
                  : transactions
                        .where((t) => t.name.toLowerCase().contains(_query))
                        .toList();

              if (_selectedCategoryId != null) {
                filtered = filtered
                    .where((t) => t.categoryId == _selectedCategoryId)
                    .toList();
              }

              final active = <ProjectedTransaction>[];
              final ended = <ProjectedTransaction>[];

              for (final t in filtered) {
                if (_isEndedPriorMonth(t, today)) {
                  ended.add(t);
                } else {
                  active.add(t);
                }
              }

              ended.sort((a, b) {
                final ae = a.recurrenceEnd!;
                final be = b.recurrenceEnd!;
                return be.compareTo(ae);
              });

              final showEndedList = _showEnded && ended.isNotEmpty;
              final itemCount =
                  active.length + (showEndedList ? 1 + ended.length : 0);

              if (active.isEmpty && !showEndedList) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isIncome
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 48,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _query.isEmpty && _selectedCategoryId == null
                            ? (ended.isNotEmpty && !_showEnded
                                  ? (isIncome
                                        ? 'No active projected incomes'
                                        : 'No active projected expenses')
                                  : (isIncome
                                        ? 'No projected incomes yet'
                                        : 'No projected expenses yet'))
                            : 'No matches',
                        style: TextStyle(
                          fontSize: 16,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (ended.isNotEmpty && !_showEnded) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _showEnded = true),
                          child: Text('Show ${ended.length} ended'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                itemCount: itemCount,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index < active.length) {
                    final tx = active[index];
                    return _ProjectedCard(
                      key: ValueKey(tx.id),
                      transaction: tx,
                      isIncome: isIncome,
                      categoryName: categoryNames[tx.categoryId] ?? 'Unknown',
                      selectedCategoryId: _selectedCategoryId,
                      forceDim: _isDimmedActiveEnded(tx, today),
                      onCategoryTap: (id) {
                        setState(() {
                          _selectedCategoryId = _selectedCategoryId == id
                              ? null
                              : id;
                        });
                      },
                    );
                  }

                  final endedIndex = index - active.length;
                  if (endedIndex == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        'Ended',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    );
                  }

                  final tx = ended[endedIndex - 1];
                  return _ProjectedCard(
                    key: ValueKey(tx.id),
                    transaction: tx,
                    isIncome: isIncome,
                    categoryName: categoryNames[tx.categoryId] ?? 'Unknown',
                    selectedCategoryId: _selectedCategoryId,
                    forceDim: true,
                    onCategoryTap: (id) {
                      setState(() {
                        _selectedCategoryId = _selectedCategoryId == id
                            ? null
                            : id;
                      });
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }
}

class _ProjectedCard extends ConsumerWidget {
  final ProjectedTransaction transaction;
  final bool isIncome;
  final String categoryName;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategoryTap;
  final bool forceDim;

  const _ProjectedCard({
    super.key,
    required this.transaction,
    required this.isIncome,
    required this.categoryName,
    required this.selectedCategoryId,
    required this.onCategoryTap,
    this.forceDim = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    String money(double v) => formatMoneyFromSettings(v, settings);

    final filterDim =
        selectedCategoryId != null &&
        selectedCategoryId != transaction.categoryId;

    final opacity = filterDim ? 0.35 : (forceDim ? 0.55 : 1.0);

    String recurrenceText = switch (transaction.recurrence) {
      RecurrenceType.none => 'One-time',
      RecurrenceType.weekly => 'Weekly',
      RecurrenceType.biweekly => 'Bi-weekly',
      RecurrenceType.monthly => 'Monthly',
      RecurrenceType.twiceMonthly => 'Twice a month',
      RecurrenceType.quarterly => 'Quarterly',
      RecurrenceType.yearly => 'Yearly',
    };

    if (transaction.recurrenceEnd != null) {
      final e = transaction.recurrenceEnd!;
      final endStr =
          '${e.year}-${e.month.toString().padLeft(2, '0')}-${e.day.toString().padLeft(2, '0')}';
      recurrenceText = '$recurrenceText · ends $endStr';
    }

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: forceDim
                    ? colors.textSecondary
                    : (transaction.isPaid
                          ? colors.successColor
                          : colors.warningColor),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => onCategoryTap(transaction.categoryId),
                        borderRadius: BorderRadius.circular(4),
                        child: Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selectedCategoryId == transaction.categoryId
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '  ·  $recurrenceText',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              isIncome
                  ? '+${money(transaction.amount)}'
                  : money(-transaction.amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isIncome ? colors.successColor : colors.dangerColor,
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: colors.textSecondary,
              ),
              onSelected: (value) async {
                final notifier = ref.read(
                  projectedTransactionsProvider.notifier,
                );

                if (value == 'delete') {
                  final name = transaction.name;
                  final toRestore = transaction;

                  await notifier.delete(transaction.id);

                  if (!context.mounted) return;
                  showUndoSnackBar(
                    context,
                    message: '"$name" deleted',
                    onUndo: () async {
                      await notifier.restore(toRestore);
                    },
                  );
                }

                if (value == 'edit') {
                  showDialog(
                    context: context,
                    builder: (context) => AddProjectedDialog(
                      type: transaction.type,
                      existing: transaction,
                    ),
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
      ),
    );
  }
}
