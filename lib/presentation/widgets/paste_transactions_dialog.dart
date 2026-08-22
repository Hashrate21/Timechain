import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/transaction_csv.dart';
import '../../domain/entities/actual_transaction.dart';
import '../../domain/entities/projected_transaction.dart';
import '../providers/app_providers.dart';

class PasteTransactionsDialog extends ConsumerStatefulWidget {
  final String? initialText;

  const PasteTransactionsDialog({super.key, this.initialText});

  @override
  ConsumerState<PasteTransactionsDialog> createState() =>
      _PasteTransactionsDialogState();
}

class _PasteTransactionsDialogState
    extends ConsumerState<PasteTransactionsDialog> {
  final _controller = TextEditingController();
  List<ParsedTxRow>? _rows;
  bool _importing = false;
  bool _resolving = false;

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  void initState() {
    super.initState();
    final initial = widget.initialText;
    if (initial != null && initial.trim().isNotEmpty) {
      _controller.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _parse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    setState(() {
      _resolving = true;
      _rows = TransactionCsv.parse(_controller.text);
    });

    try {
      final accounts = await ref.read(accountsProvider.future);
      final categories = await ref.read(categoriesProvider.future);
      final accountNames = {for (final a in accounts) _norm(a.name)};
      final categoryNames = {for (final c in categories) _norm(c.name)};

      final raw = _rows ?? [];
      final resolved = <ParsedTxRow>[];

      for (final r in raw) {
        if (!r.ok) {
          resolved.add(r);
          continue;
        }

        String? error;

        if (r.typeRaw == 'transfer') {
          final from = _norm(r.fromAccountRaw ?? '');
          final to = _norm(r.toAccountRaw ?? '');
          if (!accountNames.contains(from)) {
            error = 'unknown account "${r.fromAccountRaw}"';
          } else if (!accountNames.contains(to)) {
            error = 'unknown account "${r.toAccountRaw}"';
          }
        } else {
          if (!accountNames.contains(_norm(r.accountRaw))) {
            error = 'unknown account "${r.accountRaw}"';
          } else if (!categoryNames.contains(_norm(r.categoryRaw))) {
            error = 'unknown category "${r.categoryRaw}"';
          }
        }

        if (error != null) {
          resolved.add(
            ParsedTxRow(
              lineNumber: r.lineNumber,
              date: r.date,
              accountRaw: r.accountRaw,
              description: r.description,
              categoryRaw: r.categoryRaw,
              typeRaw: r.typeRaw,
              amount: r.amount,
              notes: r.notes,
              error: error,
              fromAccountRaw: r.fromAccountRaw,
              toAccountRaw: r.toAccountRaw,
            ),
          );
        } else {
          resolved.add(r);
        }
      }

      if (!mounted) return;
      setState(() {
        _rows = resolved;
        _resolving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _resolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load accounts/categories: $e')),
      );
    }
  }

  Future<void> _import() async {
    final rows = _rows;
    if (rows == null || rows.isEmpty) return;
    if (rows.any((r) => !r.ok)) return; // all-or-nothing

    setState(() => _importing = true);

    try {
      final accounts = await ref.read(accountsProvider.future);
      final categories = await ref.read(categoriesProvider.future);
      final accountByName = {for (final a in accounts) _norm(a.name): a.id};
      final categoryByName = {for (final c in categories) _norm(c.name): c.id};

      // Re-check right before write (still all-or-nothing)
      for (final r in rows) {
        if (r.typeRaw == 'transfer') {
          if (accountByName[_norm(r.fromAccountRaw ?? '')] == null ||
              accountByName[_norm(r.toAccountRaw ?? '')] == null) {
            throw StateError('Names changed — run Preview again');
          }
        } else {
          if (accountByName[_norm(r.accountRaw)] == null ||
              categoryByName[_norm(r.categoryRaw)] == null) {
            throw StateError('Names changed — run Preview again');
          }
        }
      }

      final notifier = ref.read(actualTransactionsProvider.notifier);

      for (final r in rows) {
        if (r.typeRaw == 'transfer') {
          await notifier.addTransfer(
            date: r.date!,
            fromAccountId: accountByName[_norm(r.fromAccountRaw!)]!,
            toAccountId: accountByName[_norm(r.toAccountRaw!)]!,
            fromAccountName: r.fromAccountRaw!,
            toAccountName: r.toAccountRaw!,
            amount: r.amount!,
          );
        } else {
          final type = r.typeRaw == 'income'
              ? TransactionType.income
              : TransactionType.expense;
          final now = DateTime.now();
          await notifier.add(
            ActualTransaction(
              id: const Uuid().v4(),
              date: r.date!,
              accountId: accountByName[_norm(r.accountRaw)]!,
              name: r.description,
              categoryId: categoryByName[_norm(r.categoryRaw)]!,
              amount: r.amount!,
              type: type,
              notes: r.notes.isEmpty ? null : r.notes,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }

      if (!mounted) return;
      final n = rows.length;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Imported $n rows')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import cancelled: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rows = _rows;
    final valid = rows?.where((r) => r.ok).length ?? 0;
    final invalid = rows?.where((r) => !r.ok).length ?? 0;
    final canImport =
        rows != null && rows.isNotEmpty && invalid == 0 && !_importing;

    return AlertDialog(
      title: const Text('Import transactions'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Columns: date, account, description, category, type, amount, notes\n'
              'Transfers: account = "From > To", type = transfer\n'
              'External: use the Untracked name from Settings (e.g. External Account)\n'
              'All rows must be valid or nothing is imported. See examples in User Guide',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Paste CSV here…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _resolving ? null : _parse,
                child: _resolving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Preview'),
              ),
            ),
            if (rows != null) ...[
              Text(
                invalid == 0
                    ? '$valid rows ready'
                    : '${rows.length} rows, $invalid issue${invalid == 1 ? '' : 's'} — fix file and Preview again',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: invalid > 0 ? colors.dangerColor : null,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  itemCount: rows.length.clamp(0, 40),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return Text(
                      r.ok
                          ? 'L${r.lineNumber}  ${r.date}  ${r.description}  ${r.amount}'
                          : 'L${r.lineNumber}  ✗ ${r.error}',
                      style: TextStyle(
                        fontSize: 12,
                        color: r.ok ? null : colors.dangerColor,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canImport ? _import : null,
          child: _importing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  invalid > 0
                      ? 'Fix $invalid issue${invalid == 1 ? '' : 's'}'
                      : 'Import $valid',
                ),
        ),
      ],
    );
  }
}
