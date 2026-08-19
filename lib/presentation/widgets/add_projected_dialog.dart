import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/projected_transaction.dart';
import '../providers/app_providers.dart';
import 'add_category_dialog.dart';

class AddProjectedDialog extends ConsumerStatefulWidget {
  final TransactionType type;
  final ProjectedTransaction? existing;

  const AddProjectedDialog({super.key, required this.type, this.existing});

  @override
  ConsumerState<AddProjectedDialog> createState() => _AddProjectedDialogState();
}

class _AddProjectedDialogState extends ConsumerState<AddProjectedDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  late RecurrenceType _recurrence;
  late int _secondDay;
  late DateTime _startDate;
  DateTime? _endDate;
  String? _selectedCategoryId;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      final tx = widget.existing!;
      _nameController.text = tx.name;
      _amountController.text = tx.amount.toStringAsFixed(2);
      _recurrence = tx.recurrence;
      _secondDay = tx.recurrenceDay2 ?? 15;
      _startDate = tx.startDate;
      _endDate = tx.recurrenceEnd;
      _selectedCategoryId = tx.categoryId;
    } else {
      _recurrence = RecurrenceType.monthly;
      _secondDay = 15;
      _startDate = DateTime.now();
      _endDate = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isIncome = widget.type == TransactionType.income;
    final categoriesAsync = ref.watch(categoriesProvider);

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
                        ? (isIncome
                              ? 'Edit Projected Income'
                              : 'Edit Projected Expense')
                        : (isIncome
                              ? 'Add Projected Income'
                              : 'Add Projected Expense'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('Name', colors),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

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
                  const SizedBox(height: 16),

                  categoriesAsync.when(
                    data: (categories) {
                      final filtered = categories
                          .where((c) => c.isIncome == isIncome && !c.isTransfer)
                          .toList();

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCategoryId,
                              decoration: _inputDecoration('Category', colors),
                              items: filtered
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedCategoryId = value);
                              },
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
                                builder: (ctx) =>
                                    AddCategoryDialog(forceIsIncome: isIncome),
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
                  const SizedBox(height: 16),

                  DropdownButtonFormField<RecurrenceType>(
                    initialValue: _recurrence,
                    decoration: _inputDecoration('Recurrence', colors),
                    items: RecurrenceType.values
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(_recurrenceLabel(r)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _recurrence = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  if (_recurrence == RecurrenceType.twiceMonthly) ...[
                    DropdownButtonFormField<int>(
                      initialValue: _secondDay,
                      decoration: _inputDecoration(
                        'Second day of month',
                        colors,
                      ),
                      items: List.generate(31, (i) => i + 1)
                          .map(
                            (d) =>
                                DropdownMenuItem(value: d, child: Text('$d')),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _secondDay = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'First occurrence uses the day from the Start Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start Date'),
                    subtitle: Text(_fmt(_startDate)),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked;
                          if (_endDate != null &&
                              _endDate!.isBefore(_startDate)) {
                            _endDate = null;
                          }
                        });
                      }
                    },
                  ),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End Date (optional)'),
                    subtitle: Text(
                      _endDate == null ? 'No end — ongoing' : _fmt(_endDate!),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_endDate != null)
                          IconButton(
                            tooltip: 'Clear end date',
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => setState(() => _endDate = null),
                          ),
                        const Icon(Icons.event_busy_rounded),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? _startDate,
                        firstDate: _startDate,
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _endDate = picked);
                      }
                    },
                  ),
                  Text(
                    'Use end date when a series stops (e.g. old rent before a price change).',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    _startDateHelperText(),
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),

                  const SizedBox(height: 28),

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

  String _startDateHelperText() {
    switch (_recurrence) {
      case RecurrenceType.monthly:
        return 'Will repeat every month on day ${_startDate.day}';
      case RecurrenceType.quarterly:
        return 'Will repeat every 3 months on day ${_startDate.day}';
      case RecurrenceType.yearly:
        return 'Will repeat every year on ${_startDate.month}/${_startDate.day}';
      case RecurrenceType.twiceMonthly:
        return 'Will repeat on day ${_startDate.day} and day $_secondDay each month';
      case RecurrenceType.weekly:
        return 'Will repeat every week starting from this date';
      case RecurrenceType.biweekly:
        return 'Will repeat every 2 weeks starting from this date';
      default:
        return 'One-time transaction on this date';
    }
  }

  InputDecoration _inputDecoration(String label, AppColors colors) {
    return InputDecoration(
      labelText: label,
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

  String _recurrenceLabel(RecurrenceType type) {
    return switch (type) {
      RecurrenceType.none => 'One-time',
      RecurrenceType.weekly => 'Weekly',
      RecurrenceType.biweekly => 'Bi-weekly',
      RecurrenceType.monthly => 'Monthly',
      RecurrenceType.twiceMonthly => 'Twice a month',
      RecurrenceType.quarterly => 'Quarterly',
      RecurrenceType.yearly => 'Yearly',
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    final notifier = ref.read(projectedTransactionsProvider.notifier);

    if (isEditing) {
      final updated = ProjectedTransaction(
        id: widget.existing!.id,
        name: _nameController.text.trim(),
        amount: double.parse(_amountController.text),
        type: widget.type,
        categoryId: _selectedCategoryId!,
        accountId: widget.existing!.accountId,
        startDate: _startDate,
        recurrence: _recurrence,
        recurrenceDay: _startDate.day,
        recurrenceDay2: _recurrence == RecurrenceType.twiceMonthly
            ? _secondDay
            : null,
        recurrenceEnd: _endDate,
        isPaid: widget.existing!.isPaid,
        notes: widget.existing!.notes,
        sortOrder: widget.existing!.sortOrder,
        createdAt: widget.existing!.createdAt,
      );

      await notifier.updateTransaction(updated);
    } else {
      final newTx = ProjectedTransaction(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        amount: double.parse(_amountController.text),
        type: widget.type,
        categoryId: _selectedCategoryId!,
        startDate: _startDate,
        recurrence: _recurrence,
        recurrenceDay: _startDate.day,
        recurrenceDay2: _recurrence == RecurrenceType.twiceMonthly
            ? _secondDay
            : null,
        recurrenceEnd: _endDate,
        createdAt: DateTime.now(),
      );

      await notifier.add(newTx);
    }

    if (mounted) Navigator.pop(context);
  }
}
