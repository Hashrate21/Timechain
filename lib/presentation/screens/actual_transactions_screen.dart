import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/snackbars.dart';
import '../../domain/entities/actual_transaction.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/projected_transaction.dart';
import '../providers/app_providers.dart';
import '../widgets/add_actual_transaction_dialog.dart';
import '../../core/utils/account_icons.dart';

class ActualTransactionsScreen extends ConsumerStatefulWidget {
  const ActualTransactionsScreen({super.key});

  @override
  ConsumerState<ActualTransactionsScreen> createState() =>
      _ActualTransactionsScreenState();
}

class _ActualTransactionsScreenState
    extends ConsumerState<ActualTransactionsScreen> {
  String _query = '';
  String? _selectedCategoryId;
  String? _selectedAccountId;
  TransactionType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final transactionsAsync = ref.watch(actualTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);

    final categoryNames = <String, String>{
      for (final c in categoriesAsync.valueOrNull ?? []) c.id: c.name,
    };
    final accountNames = <String, String>{
      for (final a in accountsAsync.valueOrNull ?? []) a.id: a.name,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 12),
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
                      hintText: 'Search transactions...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              if (_selectedCategoryId != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedCategoryId = null),
                  icon: const Icon(Icons.filter_alt_off, size: 18),
                  label: const Text('Clear category'),
                ),
              ],
              if (_selectedAccountId != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedAccountId = null),
                  icon: const Icon(Icons.filter_alt_off, size: 18),
                  label: const Text('Clear account'),
                ),
              ],
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddActualTransactionDialog(),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Transaction'),
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

        // Type filters
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _IconFilterChip(
                    tooltip: 'All types',
                    icon: Icons.filter_alt_off_rounded,
                    selected: _typeFilter == null,
                    onTap: () => setState(() => _typeFilter = null),
                  ),
                  const SizedBox(width: 8),
                  _IconFilterChip(
                    tooltip: 'Income',
                    icon: Icons.arrow_upward_rounded,
                    selected: _typeFilter == TransactionType.income,
                    iconColor: colors.successColor,
                    onTap: () =>
                        setState(() => _typeFilter = TransactionType.income),
                  ),
                  const SizedBox(width: 8),
                  _IconFilterChip(
                    tooltip: 'Expense',
                    icon: Icons.arrow_downward_rounded,
                    selected: _typeFilter == TransactionType.expense,
                    iconColor: colors.dangerColor,
                    onTap: () =>
                        setState(() => _typeFilter = TransactionType.expense),
                  ),
                  const SizedBox(width: 8),
                  _IconFilterChip(
                    tooltip: 'Transfer',
                    icon: Icons.swap_horiz_rounded,
                    selected: _typeFilter == TransactionType.transfer,
                    onTap: () =>
                        setState(() => _typeFilter = TransactionType.transfer),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Account filters
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
          child: accountsAsync.when(
            data: (accounts) {
              if (accounts.isEmpty) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _IconFilterChip(
                        tooltip: 'All accounts',
                        icon: Icons.filter_alt_off_rounded,
                        selected: _selectedAccountId == null,
                        onTap: () => setState(() => _selectedAccountId = null),
                      ),
                      const SizedBox(width: 8),
                      for (final a in accounts) ...[
                        _IconFilterChip(
                          tooltip: a.name,
                          icon: AccountIcons.data(a.iconKey),
                          selected: _selectedAccountId == a.id,
                          iconColor: AccountIcons.colorFor(a.type),
                          onTap: () => setState(() {
                            _selectedAccountId = _selectedAccountId == a.id
                                ? null
                                : a.id;
                          }),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                SizedBox(width: 6),
                SizedBox(
                  width: 110,
                  child: Text(
                    'Account',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    'Amount',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                SizedBox(width: 40),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: transactionsAsync.when(
            data: (transactions) {
              final rows = _buildRows(transactions, accountNames);

              var filtered = rows;
              if (_query.isNotEmpty) {
                filtered = filtered
                    .where((r) => r.searchText.contains(_query))
                    .toList();
              }
              if (_selectedCategoryId != null) {
                filtered = filtered
                    .where(
                      (r) =>
                          !r.isTransfer && r.categoryId == _selectedCategoryId,
                    )
                    .toList();
              }
              if (_selectedAccountId != null) {
                filtered = filtered.where((r) {
                  if (r.isTransfer) {
                    return r.fromAccountId == _selectedAccountId ||
                        r.toAccountId == _selectedAccountId;
                  }
                  return r.accountId == _selectedAccountId;
                }).toList();
              }
              if (_typeFilter != null) {
                filtered = filtered
                    .where((r) => r.type == _typeFilter)
                    .toList();
              }

              final noFilters =
                  _query.isEmpty &&
                  _selectedCategoryId == null &&
                  _selectedAccountId == null &&
                  _typeFilter == null;

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    noFilters ? 'No actual transactions yet' : 'No matches',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final row = filtered[index];
                  return _TransactionRowCard(
                    row: row,
                    categoryName: row.isTransfer
                        ? 'Transfer'
                        : (categoryNames[row.categoryId] ?? 'Unknown'),
                    selectedCategoryId: _selectedCategoryId,
                    selectedAccountId: _selectedAccountId,
                    onCategoryTap: (id) {
                      setState(() {
                        _selectedCategoryId = _selectedCategoryId == id
                            ? null
                            : id;
                      });
                    },
                    onAccountTap: (id) {
                      if (id == null) return;
                      setState(() {
                        _selectedAccountId = _selectedAccountId == id
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

  List<_ListRow> _buildRows(
    List<ActualTransaction> transactions,
    Map<String, String> accountNames,
  ) {
    final rows = <_ListRow>[];
    final seenPairs = <String>{};

    for (final t in transactions) {
      if (t.type == TransactionType.transfer && t.transferPairId != null) {
        final pairId = t.transferPairId!;
        if (seenPairs.contains(pairId)) continue;
        seenPairs.add(pairId);

        final legs = transactions
            .where((x) => x.transferPairId == pairId)
            .toList();
        ActualTransaction? fromLeg;
        ActualTransaction? toLeg;
        for (final leg in legs) {
          if (leg.amount < 0) {
            fromLeg = leg;
          } else if (leg.amount > 0) {
            toLeg = leg;
          }
        }

        if (fromLeg == null || toLeg == null) {
          final only = fromLeg ?? toLeg ?? t;
          final name = accountNames[only.accountId] ?? 'Account';
          rows.add(
            _ListRow(
              isTransfer: true,
              type: TransactionType.transfer,
              date: only.date,
              description: '$name  →  ?',
              accountLabel: name,
              accountId: only.accountId,
              fromAccountId: only.accountId,
              toAccountId: null,
              searchText: only.name.toLowerCase(),
              categoryId: only.categoryId,
              amount: only.amount.abs(),
              primary: only,
              pairId: pairId,
            ),
          );
          continue;
        }

        final fromName = accountNames[fromLeg.accountId] ?? 'Account';
        final toName = accountNames[toLeg.accountId] ?? 'Account';

        rows.add(
          _ListRow(
            isTransfer: true,
            type: TransactionType.transfer,
            date: fromLeg.date,
            description: '$fromName  →  $toName',
            accountLabel: '—',
            accountId: null,
            fromAccountId: fromLeg.accountId,
            toAccountId: toLeg.accountId,
            searchText: '$fromName $toName transfer'.toLowerCase(),
            categoryId: fromLeg.categoryId,
            amount: fromLeg.amount.abs(),
            primary: fromLeg,
            pairId: pairId,
          ),
        );
      } else if (t.type != TransactionType.transfer) {
        rows.add(
          _ListRow(
            isTransfer: false,
            type: t.type,
            date: t.date,
            description: t.name,
            accountLabel: accountNames[t.accountId] ?? '—',
            accountId: t.accountId,
            fromAccountId: null,
            toAccountId: null,
            searchText: t.name.toLowerCase(),
            categoryId: t.categoryId,
            amount: t.amount,
            primary: t,
            pairId: null,
          ),
        );
      }
    }

    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows;
  }
}

class _ListRow {
  final bool isTransfer;
  final TransactionType type;
  final DateTime date;
  final String description;
  final String accountLabel;
  final String? accountId;
  final String? fromAccountId;
  final String? toAccountId;
  final String searchText;
  final String categoryId;
  final double amount;
  final ActualTransaction primary;
  final String? pairId;

  _ListRow({
    required this.isTransfer,
    required this.type,
    required this.date,
    required this.description,
    required this.accountLabel,
    required this.accountId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.searchText,
    required this.categoryId,
    required this.amount,
    required this.primary,
    required this.pairId,
  });
}

class _IconFilterChip extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? iconColor;

  const _IconFilterChip({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.25)
                : colors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color:
                iconColor ?? (selected ? colors.primary : colors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _TransactionRowCard extends ConsumerWidget {
  final _ListRow row;
  final String categoryName;
  final String? selectedCategoryId;
  final String? selectedAccountId;
  final ValueChanged<String> onCategoryTap;
  final ValueChanged<String?> onAccountTap;

  const _TransactionRowCard({
    required this.row,
    required this.categoryName,
    required this.selectedCategoryId,
    required this.selectedAccountId,
    required this.onCategoryTap,
    required this.onAccountTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isIncome = row.type == TransactionType.income;
    final isTransfer = row.isTransfer;
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    String money(double v) => formatMoneyFromSettings(v, settings);

    final dimmedByCategory =
        !isTransfer &&
        selectedCategoryId != null &&
        selectedCategoryId != row.categoryId;
    final dimmedByAccount =
        selectedAccountId != null &&
        (isTransfer
            ? row.fromAccountId != selectedAccountId &&
                  row.toAccountId != selectedAccountId
            : row.accountId != selectedAccountId);
    final dimmed = dimmedByCategory || dimmedByAccount;

    final dateStr =
        '${row.date.year}-${row.date.month.toString().padLeft(2, '0')}-${row.date.day.toString().padLeft(2, '0')}';

    final String amountText;
    final Color amountColor;
    if (isTransfer) {
      amountText = money(row.amount);
      amountColor = colors.textPrimary;
    } else if (isIncome) {
      amountText = '+${money(row.amount)}';
      amountColor = colors.successColor;
    } else {
      amountText = money(-row.amount);
      amountColor = colors.dangerColor;
    }

    final accountSelected =
        !isTransfer &&
        row.accountId != null &&
        selectedAccountId == row.accountId;

    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                dateStr,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ),
            Expanded(
              child: Text(
                row.description,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 110,
              child: isTransfer
                  ? Text(
                      row.accountLabel,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    )
                  : InkWell(
                      onTap: () => onAccountTap(row.accountId),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        child: Text(
                          row.accountLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: accountSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: colors.cyan,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: isTransfer
                  ? Text(
                      'Transfer',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    )
                  : InkWell(
                      onTap: () => onCategoryTap(row.categoryId),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        child: Text(
                          categoryName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selectedCategoryId == row.categoryId
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                amountText,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
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
                final notifier = ref.read(actualTransactionsProvider.notifier);

                if (value == 'edit') {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        AddActualTransactionDialog(existing: row.primary),
                  );
                }

                if (value == 'delete') {
                  final label = isTransfer ? 'Transfer' : row.description;
                  final deleted = await notifier.delete(row.primary.id);

                  if (!context.mounted) return;
                  showUndoSnackBar(
                    context,
                    message: '"$label" deleted',
                    onUndo: () async {
                      await notifier.restoreMany(deleted);
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
      ),
    );
  }
}
