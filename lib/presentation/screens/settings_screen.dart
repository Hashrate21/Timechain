import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/database/budget_paths.dart';
import '../../data/database/database_helper.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/projected_transaction.dart';
import '../providers/app_providers.dart';
import '../widgets/paste_transactions_dialog.dart';
import '../../domain/entities/account.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await DatabaseHelper.instance.database;
      if (!mounted) return;
      ref.read(activeBudgetPathProvider.notifier).state =
          DatabaseHelper.instance.currentPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final colors = AppColors.of(context);
    final activePath = ref.watch(activeBudgetPathProvider);
    final budgetName = BudgetPaths.displayName(
      activePath ?? DatabaseHelper.instance.currentPath ?? 'Default',
    );

    return settingsAsync.when(
      data: (settings) {
        final showBudgetDefaults = settings.appMode != AppMode.actuals;
        final accounts = ref.watch(accountsProvider).valueOrNull ?? <Account>[];
        Account? untracked;
        for (final a in accounts) {
          if (a.isUntracked) {
            untracked = a;
            break;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(title: 'Budget file'),
              const SizedBox(height: 12),
              _SettingsCard(
                child: Column(
                  children: [
                    _SettingRow(
                      icon: Icons.folder_rounded,
                      title: 'Current budget',
                      subtitle: budgetName,
                      trailing: const SizedBox.shrink(),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Switch budget',
                      subtitle: 'Open another budget stored by this app',
                      trailing: _ValueButton(
                        value: 'Switch',
                        onTap: _switchBudgetDialog,
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.add_box_outlined,
                      title: 'Create new budget',
                      subtitle: 'Empty budget with default categories',
                      trailing: _ValueButton(
                        value: 'Create',
                        onTap: _createBudgetDialog,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              // ===== Untracked (outside this budget) =====
              const _SectionTitle(title: 'Untracked transfers'),
              const SizedBox(height: 12),
              _SettingsCard(
                child: _SettingRow(
                  icon: Icons.public_off_rounded,
                  title: untracked?.name ?? Account.defaultUntrackedName,
                  subtitle:
                      'Money to/from places you don’t track here. '
                      'Not income or expense · not on Accounts. Tap Rename.',
                  trailing: _ValueButton(
                    value: 'Rename',
                    onTap: () => _renameUntracked(untracked?.name),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const _SectionTitle(title: 'Appearance'),
              const SizedBox(height: 12),
              _SettingsCard(
                child: Column(
                  children: [
                    _SettingRow(
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark Mode',
                      subtitle: 'Use dark theme across the app',
                      trailing: Switch(
                        value: settings.themeMode == ThemeModeSetting.dark,
                        activeThumbColor: colors.primary,
                        onChanged: (value) => _updateTheme(settings, value),
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.palette_rounded,
                      title: 'Color scheme',
                      subtitle: _schemeLabel(settings.colorScheme),
                      trailing: _ValueButton(
                        value: _schemeShort(settings.colorScheme),
                        onTap: () => _cycleColorScheme(settings),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              const _SectionTitle(title: 'App Mode'),
              const SizedBox(height: 12),
              _SettingsCard(
                child: Column(
                  children: [
                    _ModeOption(
                      title: 'Combined',
                      subtitle: 'Projection + Actuals together',
                      selected: settings.appMode == AppMode.combined,
                      onTap: () => _changeMode(settings, AppMode.combined),
                    ),
                    const Divider(height: 1),
                    _ModeOption(
                      title: 'Projection Only',
                      subtitle: 'Forward-looking budget planning',
                      selected: settings.appMode == AppMode.projection,
                      onTap: () => _changeMode(settings, AppMode.projection),
                    ),
                    const Divider(height: 1),
                    _ModeOption(
                      title: 'Actuals Only',
                      subtitle: 'Track real spending & accounts',
                      selected: settings.appMode == AppMode.actuals,
                      onTap: () => _changeMode(settings, AppMode.actuals),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ===== Budget defaults (hybrid targets) =====
              if (showBudgetDefaults) ...[
                const _SectionTitle(title: 'Budget defaults'),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: _SettingRow(
                    icon: Icons.timeline_rounded,
                    title: 'Use projection as default budget',
                    subtitle: settings.useProjectionAsDefaultTarget
                        ? 'Setting a budget in the category screen will override the projection budget'
                        : 'Only amounts Set on Categories count as budget',
                    trailing: Switch(
                      value: settings.useProjectionAsDefaultTarget,
                      activeThumbColor: colors.primary,
                      onChanged: (value) => _save(
                        settings.copyWith(useProjectionAsDefaultTarget: value),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],

              const _SectionTitle(title: 'Money display'),
              const SizedBox(height: 12),
              _SettingsCard(
                child: Column(
                  children: [
                    _SettingRow(
                      icon: Icons.attach_money_rounded,
                      title: 'Currency Symbol',
                      subtitle: 'Used when symbol display is on',
                      trailing: _ValueButton(
                        value: settings.currencySymbol,
                        onTap: () {},
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.payments_outlined,
                      title: 'Show currency symbol',
                      subtitle:
                          'Prefix amounts with ${settings.currencySymbol}',
                      trailing: Switch(
                        value: settings.showCurrencySymbol,
                        activeThumbColor: colors.primary,
                        onChanged: (value) =>
                            _save(settings.copyWith(showCurrencySymbol: value)),
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.exposure_rounded,
                      title: 'Negative format',
                      subtitle: settings.negativeFormat == NegativeFormat.minus
                          ? 'Example: -1,234.00'
                          : 'Example: (1,234.00)',
                      trailing: _ValueButton(
                        value: settings.negativeFormat == NegativeFormat.minus
                            ? 'Minus'
                            : 'Parentheses',
                        onTap: () => _save(
                          settings.copyWith(
                            negativeFormat:
                                settings.negativeFormat == NegativeFormat.minus
                                ? NegativeFormat.parentheses
                                : NegativeFormat.minus,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const _SectionTitle(title: 'Projection'),
              const SizedBox(height: 12),
              _SettingsCard(
                child: Column(
                  children: [
                    _SettingRow(
                      icon: Icons.shield_rounded,
                      title: 'Safety buffer',
                      subtitle: 'Held back from safe-to-spend on the projection timeline',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message:
                                'Safe to spend = projected ending balance minus this buffer. '
                                'Does not change Accounts. '
                                'Starting balance is edited on the Projection screen.',
                            child: Icon(
                              Icons.info_outline,
                              size: 18,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ValueButton(
                            value:
                                '\$${settings.safetyBuffer.toStringAsFixed(2)}',
                            onTap: () => _editNumber(
                              title: 'Safety buffer',
                              current: settings.safetyBuffer,
                              onSaved: (value) =>
                                  _save(settings.copyWith(safetyBuffer: value)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.date_range_rounded,
                      title: 'Default range start (From)',
                      subtitle: _lookbackLabel(settings.lookbackMode),
                      trailing: _ValueButton(
                        value: _lookbackShort(settings.lookbackMode),
                        onTap: () => _cycleLookback(settings),
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.event_rounded,
                      title: 'Default range end (To)',
                      subtitle: _horizonLabel(settings.horizonMode),
                      trailing: _ValueButton(
                        value: _horizonShort(settings.horizonMode),
                        onTap: () => _cycleHorizon(settings),
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.history_rounded,
                      title: 'Remember last range',
                      subtitle:
                          'Restore From/To chips when you reopen Projection',
                      trailing: Switch(
                        value: settings.rememberProjectionRange,
                        activeThumbColor: colors.primary,
                        onChanged: (value) => _save(
                          settings.copyWith(rememberProjectionRange: value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const _SectionTitle(title: 'Data'),
              const SizedBox(height: 12),
              _SettingsCard(
                child: Column(
                  children: [
                    _SettingRow(
                      icon: Icons.download_rounded,
                      title: 'Export transactions',
                      subtitle:
                          'Save actual transactions as CSV (Excel-friendly)',
                      trailing: _ValueButton(
                        value: 'Export',
                        onTap: _exportTransactionsCsv,
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.timeline_rounded,
                      title: 'Export projections',
                      subtitle: 'Save projected occurrences in the current range as CSV',
                      trailing: _ValueButton(
                        value: 'Export',
                        onTap: _exportProjectionsCsv,
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.content_paste_rounded,
                      title: 'Paste import',
                      subtitle: 'Paste CSV / spreadsheet rows into the app',
                      trailing: _ValueButton(
                        value: 'Paste',
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => const PasteTransactionsDialog(),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.folder_open_rounded,
                      title: 'Import CSV',
                      subtitle: 'Choose a transactions CSV file to import',
                      trailing: _ValueButton(
                        value: 'Import',
                        onTap: _importTransactionsCsv,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Center(
                child: Text(
                  'Budget App  •  v0.2.0',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) =>
          Center(child: Text('Error loading settings: $err')),
    );
  }

  Future<void> _exportTransactionsCsv() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final txAsync = ref.read(actualTransactionsProvider);
      final accountsAsync = ref.read(accountsProvider);
      final categoriesAsync = ref.read(categoriesProvider);

      final txs = txAsync.valueOrNull;
      final accounts = accountsAsync.valueOrNull;
      final categories = categoriesAsync.valueOrNull;

      if (txs == null || accounts == null || categories == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Still loading data — try again in a moment'),
          ),
        );
        return;
      }

      final accountNames = {for (final a in accounts) a.id: a.name};
      final categoryNames = {for (final c in categories) c.id: c.name};

      final seenPairs = <String>{};
      final lines = <String>[
        'date,account,description,category,type,amount,notes',
      ];

      final sorted = [...txs]..sort((a, b) => b.date.compareTo(a.date));

      for (final t in sorted) {
        if (t.type == TransactionType.transfer) {
          final pairId = t.transferPairId;
          if (pairId == null || seenPairs.contains(pairId)) continue;
          seenPairs.add(pairId);

          final legs = txs.where((x) => x.transferPairId == pairId).toList();
          if (legs.length < 2) continue;

          final fromLeg = legs.firstWhere(
            (x) => x.amount < 0,
            orElse: () => legs.first,
          );
          final toLeg = legs.firstWhere(
            (x) => x.amount > 0,
            orElse: () => legs.last,
          );
          final fromName = accountNames[fromLeg.accountId] ?? 'Unknown';
          final toName = accountNames[toLeg.accountId] ?? 'Unknown';
          final amount = fromLeg.amount.abs();

          lines.add(
            [
              _csvDate(fromLeg.date),
              _csvEscape('$fromName → $toName'),
              _csvEscape(fromLeg.name),
              _csvEscape(categoryNames[fromLeg.categoryId] ?? 'Transfer'),
              'transfer',
              amount.toStringAsFixed(2),
              _csvEscape(fromLeg.notes ?? ''),
            ].join(','),
          );
          continue;
        }

        lines.add(
          [
            _csvDate(t.date),
            _csvEscape(accountNames[t.accountId] ?? ''),
            _csvEscape(t.name),
            _csvEscape(categoryNames[t.categoryId] ?? ''),
            t.type.name,
            t.amount.abs().toStringAsFixed(2),
            _csvEscape(t.notes ?? ''),
          ].join(','),
        );
      }

      final csv = lines.join('\n');

      final docs = await getApplicationDocumentsDirectory();
      final exportDir = Directory(p.join(docs.path, 'BudgetApp', 'exports'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final filePath = p.join(exportDir.path, 'transactions_$stamp.csv');
      await File(filePath).writeAsString(csv);

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Exported ${lines.length - 1} rows to:\n$filePath'),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _exportProjectionsCsv() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Prefer the already-expanded provider when available; fall back to repo + service.
      final occurrencesAsync = ref.read(projectionOccurrencesProvider);
      final paidIdsAsync = ref.read(paidOccurrenceIdsProvider);
      final skippedIdsAsync = ref.read(skippedOccurrenceIdsProvider);
      final accountsAsync = ref.read(accountsProvider);
      final categoriesAsync = ref.read(categoriesProvider);
      final templatesAsync = ref.read(
        projectedTransactionsProvider,
      ); // list of ProjectedTransaction
      final range = ref.read(projectionRangeProvider);

      final occurrences = occurrencesAsync.valueOrNull;
      final paidIds = paidIdsAsync.valueOrNull ?? <String>{};
      final skippedIds = skippedIdsAsync.valueOrNull ?? <String>{};
      final accounts = accountsAsync.valueOrNull;
      final categories = categoriesAsync.valueOrNull;
      final templates = templatesAsync.valueOrNull;

      if (occurrences == null ||
          accounts == null ||
          categories == null ||
          templates == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Still loading data — try again in a moment'),
          ),
        );
        return;
      }

      final accountNames = {for (final a in accounts) a.id: a.name};
      final categoryNames = {for (final c in categories) c.id: c.name};
      final templateById = {for (final t in templates) t.id: t};

      final lines = <String>[
        'date,account,description,category,type,amount,notes,paid,skipped,recurrence,series_id',
      ];

      // occurrences are already sorted by ProjectionService
      for (final occ in occurrences) {
        final template = templateById[occ.templateId];
        final accountName = accountNames[template?.accountId] ?? '';
        final isPaid = paidIds.contains(occ.id);
        final isSkipped = skippedIds.contains(occ.id);

        lines.add(
          [
            _csvDate(occ.date),
            _csvEscape(accountName),
            _csvEscape(occ.name),
            _csvEscape(categoryNames[occ.categoryId] ?? ''),
            occ.type.name,
            occ.amount.abs().toStringAsFixed(2),
            _csvEscape(template?.notes ?? ''),
            isPaid ? 'true' : 'false',
            isSkipped ? 'true' : 'false',
            occ.recurrence.name,
            occ.templateId,
          ].join(','),
        );
      }

      final csv = lines.join('\n');

      final docs = await getApplicationDocumentsDirectory();
      final exportDir = Directory(p.join(docs.path, 'BudgetApp', 'exports'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final filePath = p.join(exportDir.path, 'projections_$stamp.csv');
      await File(filePath).writeAsString(csv);

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${lines.length - 1} projected rows '
            '(${_csvDate(range.start)} → ${_csvDate(range.end)}) to:\n$filePath',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  String _csvDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _importTransactionsCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    String text;
    if (file.bytes != null) {
      text = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      text = await File(file.path!).readAsString();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not read file')));
      return;
    }

    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => PasteTransactionsDialog(initialText: text),
    );
  }

  Future<void> _switchBudgetDialog() async {
    final paths = await BudgetPaths.listBudgetPaths();
    if (!mounted) return;
    final current = DatabaseHelper.instance.currentPath;

    final chosen = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Switch budget'),
          content: SizedBox(
            width: 360,
            child: paths.isEmpty
                ? const Text('No budgets found.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: paths.length,
                    itemBuilder: (context, i) {
                      final path = paths[i];
                      final name = BudgetPaths.displayName(path);
                      final selected = path == current;
                      return ListTile(
                        title: Text(name),
                        subtitle: Text(
                          p.basename(path),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: selected
                            ? Icon(Icons.check, color: AppColors.primaryBlue)
                            : null,
                        onTap: () => Navigator.pop(context, path),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (chosen == null || chosen == current) return;
    await switchBudget(ref, chosen);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Switched to ${BudgetPaths.displayName(chosen)}')),
    );
  }

  Future<void> _createBudgetDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create budget'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Household',
            ),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;
    try {
      await createBudget(ref, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Created "$name"')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String _lookbackShort(ProjectionLookbackMode m) {
    switch (m) {
      case ProjectionLookbackMode.monthStart:
        return '1st';
      case ProjectionLookbackMode.lastPay:
        return '\$←';
      case ProjectionLookbackMode.custom:
        return 'Custom';
    }
  }

  String _lookbackLabel(ProjectionLookbackMode m) {
    switch (m) {
      case ProjectionLookbackMode.monthStart:
        return 'Start of this month';
      case ProjectionLookbackMode.lastPay:
        return 'Since last projected income';
      case ProjectionLookbackMode.custom:
        return 'Custom date (set on Projection)';
    }
  }

  String _horizonShort(ProjectionHorizonMode m) {
    switch (m) {
      case ProjectionHorizonMode.eom:
        return 'EOM';
      case ProjectionHorizonMode.nextPay:
        return '→\$';
      case ProjectionHorizonMode.custom:
        return 'Custom';
    }
  }

  String _horizonLabel(ProjectionHorizonMode m) {
    switch (m) {
      case ProjectionHorizonMode.eom:
        return 'End of this month';
      case ProjectionHorizonMode.nextPay:
        return 'Day before next projected income';
      case ProjectionHorizonMode.custom:
        return 'Custom date (set on Projection)';
    }
  }

  Future<void> _cycleLookback(AppSettings settings) async {
    const order = ProjectionLookbackMode.values;
    final i = order.indexOf(settings.lookbackMode);
    final next = order[(i + 1) % order.length];
    await _save(settings.copyWith(lookbackMode: next));
    ref.read(projectionLookbackModeProvider.notifier).state = next;
  }

  Future<void> _cycleHorizon(AppSettings settings) async {
    const order = ProjectionHorizonMode.values;
    final i = order.indexOf(settings.horizonMode);
    final next = order[(i + 1) % order.length];
    await _save(settings.copyWith(horizonMode: next));
    ref.read(projectionHorizonModeProvider.notifier).state = next;
  }

  Future<void> _renameUntracked(String? currentName) async {
    final controller = TextEditingController(
      text: currentName ?? Account.defaultUntrackedName,
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename Untracked'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Kids 529, Brokerage',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      await ref
          .read(accountRepositoryProvider)
          .renameUntracked(controller.text);
      ref.invalidate(accountsProvider);
    }
    controller.dispose();
  }

  Future<void> _save(AppSettings updated) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.updateSettings(updated);
    ref.invalidate(settingsProvider);
  }

  Future<void> _editNumber({
    required String title,
    required double current,
    required Future<void> Function(double) onSaved,
  }) async {
    final controller = TextEditingController(text: current.toStringAsFixed(2));

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = double.tryParse(controller.text);
                if (value != null) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await onSaved(result);
    }
  }

  Future<void> _changeMode(AppSettings current, AppMode newMode) async {
    await _save(
      current.copyWith(
        appMode: newMode,
        useProjectionAsDefaultTarget: newMode == AppMode.actuals
            ? false
            : current.useProjectionAsDefaultTarget,
      ),
    );
  }

  Future<void> _updateTheme(AppSettings current, bool isDark) async {
    await _save(
      current.copyWith(
        themeMode: isDark ? ThemeModeSetting.dark : ThemeModeSetting.light,
      ),
    );
  }

  String _schemeLabel(AppColorScheme s) => switch (s) {
    AppColorScheme.defaultBlue => 'Default Blue',
    AppColorScheme.neonNights => 'Tokyo Neon Nights',
    AppColorScheme.orange => 'Orange',
    AppColorScheme.mono => 'Mono',
  };

  String _schemeShort(AppColorScheme s) => switch (s) {
    AppColorScheme.defaultBlue => 'Blue',
    AppColorScheme.neonNights => 'Neon',
    AppColorScheme.orange => 'Orange',
    AppColorScheme.mono => 'Mono',
  };

  Future<void> _cycleColorScheme(AppSettings settings) async {
    const order = AppColorScheme.values;
    final i = order.indexOf(settings.colorScheme);
    final next = order[(i + 1) % order.length];
    await _save(settings.copyWith(colorScheme: next));
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ValueButton extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _ValueButton({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        backgroundColor: colors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ModeOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: colors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
