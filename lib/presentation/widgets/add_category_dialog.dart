import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/category_color.dart';
import '../../data/repositories/category_budget_repository.dart';
import '../../domain/entities/category.dart';
import '../providers/app_providers.dart';

class AddCategoryDialog extends ConsumerStatefulWidget {
  final Category? existing;
  final bool?
  forceIsIncome; // true = income, false = expense, null = user picks

  const AddCategoryDialog({super.key, this.existing, this.forceIsIncome});

  @override
  ConsumerState<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  bool _isIncome = false;
  String _color = '#3B82F6';
  late DateTime _budgetMonth; // first of month

  bool get isEditing => widget.existing != null;

  final List<String> _colorOptions = [
    '#3B82F6',
    '#0EA5E9',
    '#06B6D4',
    '#14B8A6',
    '#22FFF7',
    '#10B981',
    '#22C55E',
    '#84CC16',
    '#006104',
    '#6366F1',
    '#8B5CF6',
    '#A855F7',
    '#D946EF',
    '#EC4899',
    '#F472B6',
    '#FDFD96',
    '#FFFF00',
    '#EAB308',
    '#F59E0B',
    '#F97316',
    '#64748B',
    '#94A3B8',
  ];

  /// Stored as "#START|#END"
  final List<String> _gradientOptions = [
    '#2472EE|#07c6e7',
    '#06B6D4|#142feb',
    '#7e46ff|#468bfc',
    '#EC4899|#8B5CF6',
    '#F59E0B|#EF4444',
    '#F97316|#f5e40b',
    '#19c58c|#06B6D4',
    '#22C55E|#84CC16',
    '#5357f8|#b66efb',
    '#ee3737|#ffa651',
    '#44638e|#94A3B8',
    '#f98800|#ffca4d',
    '#fd3df0|#186af0',
    '#fd3df0|#35dc40',
    '#ded62f|#35dc40',
    '#35dc40|#7835dc',
  ];

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _budgetMonth = DateTime(now.year, now.month);

    if (isEditing) {
      final c = widget.existing!;
      _nameController.text = c.name;
      _isIncome = c.isIncome;
      _color = c.color;
      _loadBudget(c.id);
    }
    if (widget.forceIsIncome != null) {
      _isIncome = widget.forceIsIncome!;
    }
  }

  String get _yearMonth => CategoryBudgetRepository.yearMonthKey(_budgetMonth);

  Future<void> _loadBudget(String categoryId) async {
    try {
      final repo = ref.read(categoryBudgetRepositoryProvider);
      final amount = await repo.getBudget(categoryId, yearMonth: _yearMonth);
      if (!mounted) return;
      _budgetController.text = amount != null ? amount.toStringAsFixed(2) : '';
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
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
                    isEditing ? 'Edit Category' : 'Add Category',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('Category Name', colors),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  if (widget.forceIsIncome == null) ...[
                    DropdownButtonFormField<bool>(
                      initialValue: _isIncome,
                      decoration: _inputDecoration('Type', colors),
                      items: const [
                        DropdownMenuItem(value: false, child: Text('Expense')),
                        DropdownMenuItem(value: true, child: Text('Income')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _isIncome = value);
                      },
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      _isIncome ? 'Type: Income' : 'Type: Expense',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!_isIncome) ...[
                    Text(
                      'Budget applies to',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous month',
                          onPressed: () {
                            setState(() {
                              _budgetMonth = DateTime(
                                _budgetMonth.year,
                                _budgetMonth.month - 1,
                              );
                            });
                            if (isEditing) {
                              _loadBudget(widget.existing!.id);
                            } else {
                              _budgetController.clear();
                            }
                          },
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            '${_monthNames[_budgetMonth.month - 1]} ${_budgetMonth.year}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next month',
                          onPressed: () {
                            setState(() {
                              _budgetMonth = DateTime(
                                _budgetMonth.year,
                                _budgetMonth.month + 1,
                              );
                            });
                            if (isEditing) {
                              _loadBudget(widget.existing!.id);
                            } else {
                              _budgetController.clear();
                            }
                          },
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _budgetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        'Monthly Budget (optional)',
                        colors,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (double.tryParse(v) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Only applies to ${_monthNames[_budgetMonth.month - 1]} ${_budgetMonth.year}. '
                      'You can set next month early without changing this month.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Color',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in _colorOptions) _colorDot(c, colors),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Gradients',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in _gradientOptions) _colorDot(c, colors),
                    ],
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

  Widget _colorDot(String value, AppColors colors) {
    final selected = _color == value;
    final parsed = CategoryColor.parse(value, fallback: colors.primary);

    return GestureDetector(
      onTap: () => setState(() => _color = value),
      child: Container(
        width: 32,
        height: 32,
        decoration: parsed.decoration().copyWith(
          border: selected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: parsed.start.withValues(alpha: 0.45),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
      ),
    );
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final categoryRepo = ref.read(categoryRepositoryProvider);
    final budgetRepo = ref.read(categoryBudgetRepositoryProvider);
    final ym = _yearMonth;

    String categoryId;

    if (isEditing) {
      categoryId = widget.existing!.id;
      final updated = Category(
        id: categoryId,
        name: _nameController.text.trim(),
        color: _color,
        icon: widget.existing!.icon,
        isIncome: _isIncome,
        isTransfer: widget.existing!.isTransfer,
        sortOrder: widget.existing!.sortOrder,
        createdAt: widget.existing!.createdAt,
      );
      await categoryRepo.update(updated);
    } else {
      final newCategory = await categoryRepo.create(
        name: _nameController.text.trim(),
        color: _color,
        isIncome: _isIncome,
      );
      categoryId = newCategory.id;
    }

    final budgetText = _budgetController.text.trim();
    if (!_isIncome && budgetText.isNotEmpty) {
      final amount = double.parse(budgetText);
      await budgetRepo.setBudget(
        categoryId: categoryId,
        amount: amount,
        yearMonth: ym,
      );
    } else if (!_isIncome) {
      await budgetRepo.clearBudget(categoryId, yearMonth: ym);
    }

    ref.invalidate(categoriesProvider);
    ref.invalidate(categoryBudgetsProvider(ym));
    ref.invalidate(currentMonthCategoryBudgetsProvider);

    if (mounted) Navigator.pop(context, categoryId);
  }
}
