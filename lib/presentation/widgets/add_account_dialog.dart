import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/account_icons.dart';
import '../../domain/entities/account.dart';
import '../providers/app_providers.dart';

class AddAccountDialog extends ConsumerStatefulWidget {
  final Account? existing;

  const AddAccountDialog({super.key, this.existing});

  @override
  ConsumerState<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends ConsumerState<AddAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  AccountType _type = AccountType.asset;
  late String _iconKey;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final a = widget.existing!;
      _nameController.text = a.name;
      _type = a.type;
      _balanceController.text = a.startingBalance.toStringAsFixed(2);
      _iconKey = a.iconKey;
    } else {
      _balanceController.text = '0.00';
      _iconKey = Account.defaultIconFor(_type);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final keys = AccountIcons.keysFor(_type);

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
                    isEditing ? 'Edit Account' : 'Add Account',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('Account Name', colors),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AccountType>(
                    initialValue: _type,
                    decoration: _inputDecoration('Type', colors),
                    items: const [
                      DropdownMenuItem(
                        value: AccountType.asset,
                        child: Text('Asset (checking, savings, cash)'),
                      ),
                      DropdownMenuItem(
                        value: AccountType.liability,
                        child: Text('Liability (credit card, loan)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _type = v;
                        final allowed = AccountIcons.keysFor(v);
                        if (!allowed.contains(_iconKey)) {
                          _iconKey = Account.defaultIconFor(v);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Icon',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final key in keys)
                        InkWell(
                          onTap: () => setState(() => _iconKey = key),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _iconKey == key
                                  ? colors.primary.withValues(alpha: 0.2)
                                  : colors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _iconKey == key
                                    ? colors.primary
                                    : colors.border,
                                width: _iconKey == key ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              AccountIcons.data(key),
                              color: AccountIcons.colorFor(_type),
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _balanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: _inputDecoration('Starting balance', colors),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v.trim()) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Liabilities can be entered as negative amounts. '
                    'Display color follows the sign (negative = red).',
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

    final repo = ref.read(accountRepositoryProvider);
    final name = _nameController.text.trim();
    final balance = double.parse(_balanceController.text.trim());

    String accountId;

    if (isEditing) {
      accountId = widget.existing!.id;
      final updated = Account(
        id: accountId,
        name: name,
        type: _type,
        startingBalance: balance,
        currency: widget.existing!.currency,
        isActive: widget.existing!.isActive,
        sortOrder: widget.existing!.sortOrder,
        createdAt: widget.existing!.createdAt,
        iconKey: _iconKey,
      );
      await repo.update(updated);
    } else {
      final created = await repo.create(
        name: name,
        type: _type,
        startingBalance: balance,
        iconKey: _iconKey,
      );
      accountId = created.id;
    }

    ref.invalidate(accountsProvider);

    if (mounted) Navigator.pop(context, accountId);
  }
}
