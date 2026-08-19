import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/actual_transaction.dart';
import '../../domain/entities/projected_transaction.dart';
import '../providers/app_providers.dart';
import 'add_account_dialog.dart';
import 'add_category_dialog.dart';

class AddActualTransactionDialog extends ConsumerStatefulWidget {
  final ActualTransaction? existing;

  const AddActualTransactionDialog({super.key, this.existing});

  @override
  ConsumerState<AddActualTransactionDialog> createState() =>
      _AddActualTransactionDialogState();
}

class _AddActualTransactionDialogState
    extends ConsumerState<AddActualTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  late TransactionType _type;
  late DateTime _date;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String? _fromAccountId;
  String? _toAccountId;
  String? _editPairId;

  bool get isEditing => widget.existing != null;
  bool get isTransfer => _type == TransactionType.transfer;

  static const _fieldGap = 16.0;
  static const _labelGap = 6.0;
  static const _arrowGap = 10.0;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      final tx = widget.existing!;
      _date = tx.date;

      if (tx.type == TransactionType.transfer || tx.transferPairId != null) {
        _type = TransactionType.transfer;
        _editPairId = tx.transferPairId;
        _amountController.text = tx.amount.abs().toStringAsFixed(2);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _hydrateTransferLegs(tx);
        });
      } else {
        _type = tx.type;
        _nameController.text = tx.name;
        _amountController.text = tx.amount.toStringAsFixed(2);
        _selectedAccountId = tx.accountId;
        _selectedCategoryId = tx.categoryId;
      }
    } else {
      _type = TransactionType.expense;
      _date = DateTime.now();
    }
  }

  void _hydrateTransferLegs(ActualTransaction tx) {
    final all = ref.read(actualTransactionsProvider).valueOrNull ?? [];
    final pairId = tx.transferPairId;
    if (pairId == null) return;

    final legs = all.where((t) => t.transferPairId == pairId).toList();
    ActualTransaction? fromLeg;
    ActualTransaction? toLeg;

    for (final leg in legs) {
      if (leg.amount < 0) {
        fromLeg = leg;
      } else {
        toLeg = leg;
      }
    }

    fromLeg ??= legs.where((l) => l.name.startsWith('Transfer to')).firstOrNull;
    toLeg ??= legs.where((l) => l.name.startsWith('Transfer from')).firstOrNull;

    if (!mounted) return;
    setState(() {
      _fromAccountId = fromLeg?.accountId ?? tx.accountId;
      _toAccountId = toLeg?.accountId;
      final amt = (fromLeg ?? toLeg ?? tx).amount.abs();
      _amountController.text = amt.toStringAsFixed(2);
      _date = (fromLeg ?? tx).date;
      _editPairId = pairId;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _accountName(List<Account> accounts, String? id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return 'Account';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final isIncome = _type == TransactionType.income;

    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: colors.textSecondary,
    );

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing
                        ? (isTransfer ? 'Edit Transfer' : 'Edit Transaction')
                        : 'Add Actual Transaction',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),

                  DropdownButtonFormField<TransactionType>(
                    initialValue: _type,
                    decoration: _inputDecoration('Type', colors),
                    items: [
                      if (!isTransfer || !isEditing) ...[
                        const DropdownMenuItem(
                          value: TransactionType.expense,
                          child: Text('Expense'),
                        ),
                        const DropdownMenuItem(
                          value: TransactionType.income,
                          child: Text('Income'),
                        ),
                      ],
                      if (!isEditing || isTransfer)
                        const DropdownMenuItem(
                          value: TransactionType.transfer,
                          child: Text('Transfer'),
                        ),
                    ],
                    onChanged: isEditing
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _type = value;
                                _selectedCategoryId = null;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: _fieldGap),

                  if (!isTransfer) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: _inputDecoration('Description', colors),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: _fieldGap),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration('Amount', colors),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: _fieldGap),
                    accountsAsync.when(
                      data: (accounts) => _accountRow(
                        colors: colors,
                        accounts: accounts,
                        value: _selectedAccountId,
                        onChanged: (v) =>
                            setState(() => _selectedAccountId = v),
                        onCreated: (id) =>
                            setState(() => _selectedAccountId = id),
                        validator: (v) =>
                            v == null ? 'Select an account' : null,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Error loading accounts'),
                    ),
                    const SizedBox(height: _fieldGap),
                    categoriesAsync.when(
                      data: (categories) {
                        final filtered = categories
                            .where(
                              (c) => c.isIncome == isIncome && !c.isTransfer,
                            )
                            .toList();
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedCategoryId,
                                decoration: _inputDecoration(
                                  'Category',
                                  colors,
                                ),
                                items: filtered
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _selectedCategoryId = value),
                                validator: (v) =>
                                    v == null ? 'Select a category' : null,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Add category',
                              onPressed: () async {
                                final id = await showDialog<String>(
                                  context: context,
                                  builder: (ctx) => AddCategoryDialog(
                                    forceIsIncome: isIncome,
                                  ),
                                );
                                if (id != null && mounted) {
                                  setState(() => _selectedCategoryId = id);
                                }
                              },
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Error loading categories'),
                    ),
                    const SizedBox(height: _fieldGap),
                  ] else ...[
                    accountsAsync.when(
                      data: (accounts) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From', style: labelStyle),
                            const SizedBox(height: _labelGap),
                            _accountRow(
                              colors: colors,
                              accounts: accounts,
                              value: _fromAccountId,
                              onChanged: (v) =>
                                  setState(() => _fromAccountId = v),
                              onCreated: (id) =>
                                  setState(() => _fromAccountId = id),
                              validator: (v) {
                                if (v == null) return 'Select account';
                                if (v == _toAccountId) {
                                  return 'Must differ from To';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: _arrowGap),
                            Center(
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                size: 20,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(height: _arrowGap),
                            Text('Amount', style: labelStyle),
                            const SizedBox(height: _labelGap),
                            TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                null,
                                colors,
                              ).copyWith(hintText: '0.00'),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Required';
                                }
                                final n = double.tryParse(v);
                                if (n == null || n <= 0) {
                                  return 'Enter amount > 0';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: _arrowGap),
                            Center(
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                size: 20,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(height: _arrowGap),
                            Text('To', style: labelStyle),
                            const SizedBox(height: _labelGap),
                            _accountRow(
                              colors: colors,
                              accounts: accounts,
                              value: _toAccountId,
                              onChanged: (v) =>
                                  setState(() => _toAccountId = v),
                              onCreated: (id) =>
                                  setState(() => _toAccountId = id),
                              validator: (v) {
                                if (v == null) return 'Select account';
                                if (v == _fromAccountId) {
                                  return 'Must differ from From';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Moves money between accounts. Not counted as income or spending.',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Error loading accounts'),
                    ),
                    const SizedBox(height: _fieldGap),
                  ],

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Date'),
                    subtitle: Text(_fmt(_date)),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(isEditing ? 'Update' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _accountRow({
    required AppColors colors,
    required List<Account> accounts,
    required String? value,
    required ValueChanged<String?> onChanged,
    required ValueChanged<String> onCreated,
    required String? Function(String?) validator,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: accounts.isEmpty
              ? InputDecorator(
                  decoration: _inputDecoration('Account', colors),
                  child: Text(
                    'No accounts yet — tap +',
                    style: TextStyle(fontSize: 14, color: colors.textSecondary),
                  ),
                )
              : DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: _inputDecoration('Account', colors),
                  items: accounts
                      .map(
                        (a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: onChanged,
                  validator: validator,
                ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Add account',
          onPressed: () async {
            final id = await showDialog<String>(
              context: context,
              builder: (ctx) => const AddAccountDialog(),
            );
            if (id != null && mounted) onCreated(id);
          },
          icon: Icon(Icons.add_circle_outline, color: colors.primary),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String? label, AppColors colors) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: colors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.border),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(actualTransactionsProvider.notifier);

    if (isTransfer) {
      if (_fromAccountId == null || _toAccountId == null) return;
      final accounts = ref.read(accountsProvider).valueOrNull ?? [];
      final amount = double.parse(_amountController.text);

      if (_editPairId != null) {
        await notifier.updateTransfer(
          pairId: _editPairId!,
          date: _date,
          fromAccountId: _fromAccountId!,
          toAccountId: _toAccountId!,
          fromAccountName: _accountName(accounts, _fromAccountId),
          toAccountName: _accountName(accounts, _toAccountId),
          amount: amount,
        );
      } else {
        await notifier.addTransfer(
          date: _date,
          fromAccountId: _fromAccountId!,
          toAccountId: _toAccountId!,
          fromAccountName: _accountName(accounts, _fromAccountId),
          toAccountName: _accountName(accounts, _toAccountId),
          amount: amount,
        );
      }
    } else {
      if (_selectedAccountId == null || _selectedCategoryId == null) {
        return;
      }

      if (isEditing) {
        final updated = ActualTransaction(
          id: widget.existing!.id,
          date: _date,
          accountId: _selectedAccountId!,
          name: _nameController.text.trim(),
          categoryId: _selectedCategoryId!,
          amount: double.parse(_amountController.text),
          type: _type,
          notes: widget.existing!.notes,
          transferPairId: widget.existing!.transferPairId,
          createdAt: widget.existing!.createdAt,
          updatedAt: DateTime.now(),
        );
        await notifier.updateTransaction(updated);
      } else {
        final newTx = ActualTransaction(
          id: const Uuid().v4(),
          date: _date,
          accountId: _selectedAccountId!,
          name: _nameController.text.trim(),
          categoryId: _selectedCategoryId!,
          amount: double.parse(_amountController.text),
          type: _type,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await notifier.add(newTx);
      }
    }

    if (mounted) Navigator.pop(context);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final i = iterator;
    if (!i.moveNext()) return null;
    return i.current;
  }
}
