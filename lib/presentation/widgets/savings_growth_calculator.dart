import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/app_settings.dart';
import '../providers/app_providers.dart';

class _GrowthRow {
  final DateTime date;
  final double contribution;
  final double growth;
  final double balance;

  const _GrowthRow({
    required this.date,
    required this.contribution,
    required this.growth,
    required this.balance,
  });
}

class SavingsGrowthCalculator extends ConsumerStatefulWidget {
  const SavingsGrowthCalculator({super.key});

  @override
  ConsumerState<SavingsGrowthCalculator> createState() =>
      _SavingsGrowthCalculatorState();
}

class _SavingsGrowthCalculatorState
    extends ConsumerState<SavingsGrowthCalculator> {
  /// null = Custom
  String? _accountId;

  final _balanceCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '7');
  final _contribCtrl = TextEditingController();
  final _extraCtrl = TextEditingController(text: '0');
  final _monthsCtrl = TextEditingController(text: '120');
  final _increaseCtrl = TextEditingController();

  int _increaseEveryMonths = 12;
  bool _increaseOnAnniversary = true;
  bool _showAdvanced = false;
  bool _showBreakdown = false;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  List<_GrowthRow> _schedule = [];
  String? _error;
  bool _loaded = false;

  static const bool _contribThenGrow = true;

  @override
  void dispose() {
    _balanceCtrl.dispose();
    _rateCtrl.dispose();
    _contribCtrl.dispose();
    _extraCtrl.dispose();
    _monthsCtrl.dispose();
    _increaseCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _restorePreset(accountId: null);
    }
  }

  String _numStr(dynamic v) {
    if (v is num) {
      if (v == v.roundToDouble()) return v.toStringAsFixed(0);
      return v.toString();
    }
    return '$v';
  }

  Future<void> _restorePreset({String? accountId}) async {
    final repo = ref.read(calculatorPresetRepositoryProvider);
    final map = await repo.getPreset(
      calculator: 'savings',
      accountId: accountId,
    );
    final data =
        map ??
        (accountId != null
            ? await repo.getPreset(calculator: 'savings', accountId: null)
            : null);
    if (!mounted || data == null) return;

    setState(() {
      if (data['annual_return'] != null) {
        _rateCtrl.text = _numStr(data['annual_return']);
      }
      if (data['monthly_savings'] != null) {
        _contribCtrl.text = _numStr(data['monthly_savings']);
      }
      if (data['extra'] != null) {
        _extraCtrl.text = _numStr(data['extra']);
      }
      if (data['months'] != null) {
        _monthsCtrl.text = '${data['months']}';
      }
      if (data['increase_pct'] != null) {
        _increaseCtrl.text = _numStr(data['increase_pct']);
      } else {
        _increaseCtrl.clear();
      }
      if (data['increase_every_months'] is int) {
        final n = data['increase_every_months'] as int;
        if ([1, 3, 6, 12, 24].contains(n)) {
          _increaseEveryMonths = n;
        }
      }
      if (data['increase_on_anniversary'] is bool) {
        _increaseOnAnniversary = data['increase_on_anniversary'] as bool;
      }
      if (data['show_breakdown'] is bool) {
        _showBreakdown = data['show_breakdown'] as bool;
      }
      if (data['start_year'] is int && data['start_month'] is int) {
        _startDate = DateTime(
          data['start_year'] as int,
          data['start_month'] as int,
          1,
        );
      }
      if (accountId == null && data['balance'] != null) {
        _balanceCtrl.text = _numStr(data['balance']);
      }
    });
  }

  Future<void> _persistPreset() async {
    final repo = ref.read(calculatorPresetRepositoryProvider);
    final payload = <String, dynamic>{
      'annual_return': _parse(_rateCtrl),
      'monthly_savings': _parse(_contribCtrl),
      'extra': _parse(_extraCtrl) ?? 0,
      'months': int.tryParse(_monthsCtrl.text.trim()),
      'increase_pct': _parse(_increaseCtrl),
      'increase_every_months': _increaseEveryMonths,
      'increase_on_anniversary': _increaseOnAnniversary,
      'show_breakdown': _showBreakdown,
      'start_year': _startDate.year,
      'start_month': _startDate.month,
      'last_account_id': _accountId,
      if (_accountId == null) 'balance': _parse(_balanceCtrl),
    };

    await repo.savePreset(
      calculator: 'savings',
      accountId: null,
      payload: {...payload, 'balance': _parse(_balanceCtrl)},
    );

    if (_accountId != null) {
      await repo.savePreset(
        calculator: 'savings',
        accountId: _accountId,
        payload: payload,
      );
    }
  }

  Future<void> _onAccountChanged(
    String? id,
    Map<String, double> balances,
  ) async {
    setState(() {
      _accountId = id;
      _schedule = [];
      _error = null;
      if (id != null) {
        final bal = balances[id] ?? 0;
        _balanceCtrl.text = bal.toStringAsFixed(2);
      }
    });
    await _restorePreset(accountId: id);
    if (id != null && mounted) {
      final bal = balances[id] ?? 0;
      setState(() {
        _balanceCtrl.text = bal.toStringAsFixed(2);
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, 1);
    });
  }

  double? _parse(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  bool _shouldIncrease(int monthIndex, DateTime date) {
    final n = _increaseEveryMonths;
    if (n <= 0) return false;

    if (_increaseOnAnniversary) {
      return monthIndex % n == 0;
    }
    return (date.month - 1) % n == 0;
  }

  Future<void> _calculate() async {
    final balance = _parse(_balanceCtrl) ?? 0;
    final rate = _parse(_rateCtrl) ?? 0;
    final contrib = _parse(_contribCtrl) ?? 0;
    final extra = _parse(_extraCtrl) ?? 0;
    final months = int.tryParse(_monthsCtrl.text.trim());
    final increasePct = _parse(_increaseCtrl) ?? 0;

    if (balance < 0) {
      setState(() {
        _error = 'Starting balance cannot be negative.';
        _schedule = [];
      });
      return;
    }
    if (rate < 0) {
      setState(() {
        _error = 'Growth rate cannot be negative.';
        _schedule = [];
      });
      return;
    }
    if (increasePct < 0) {
      setState(() {
        _error = 'Contribution increase % cannot be negative.';
        _schedule = [];
      });
      return;
    }
    if (months == null || months <= 0) {
      setState(() {
        _error = 'Enter how many months to project (e.g. 120 for 10 years).';
        _schedule = [];
      });
      return;
    }
    if (months > 600) {
      setState(() {
        _error = 'Max projection is 600 months (50 years).';
        _schedule = [];
      });
      return;
    }

    final monthlyRate = rate / 100 / 12;
    var monthlyAdd = contrib + extra;

    final rows = <_GrowthRow>[];
    var bal = balance;
    var date = _startDate;

    for (var i = 0; i < months; i++) {
      if (increasePct > 0 && i > 0 && _shouldIncrease(i, date)) {
        monthlyAdd *= (1 + increasePct / 100);
      }

      final contribution = monthlyAdd;
      late final double growth;

      if (_contribThenGrow) {
        bal += contribution;
        growth = monthlyRate == 0 ? 0.0 : bal * monthlyRate;
        bal += growth;
      } else {
        growth = monthlyRate == 0 ? 0.0 : bal * monthlyRate;
        bal += growth + contribution;
      }

      rows.add(
        _GrowthRow(
          date: date,
          contribution: contribution,
          growth: growth,
          balance: bal,
        ),
      );

      date = DateTime(date.year, date.month + 1, 1);
    }

    setState(() {
      _error = null;
      _schedule = rows;
    });

    await _persistPreset();
  }

  Future<void> _exportCsv() async {
    if (_schedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calculate a schedule first.')),
      );
      return;
    }

    final buf = StringBuffer();
    buf.writeln('month,year,contribution,growth,balance');
    for (final r in _schedule) {
      buf.writeln(
        '${r.date.month},${r.date.year},'
        '${r.contribution.toStringAsFixed(2)},'
        '${r.growth.toStringAsFixed(2)},'
        '${r.balance.toStringAsFixed(2)}',
      );
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final name =
          'savings_schedule_${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}.csv';
      final file = File('${dir.path}/$name');
      await file.writeAsString(buf.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved: ${file.path}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    String money(double v) => formatMoneyFromSettings(v, settings);

    final accountsAsync = ref.watch(accountsProvider);
    final balances =
        ref.watch(accountBalancesProvider).valueOrNull ?? <String, double>{};

    final accounts = (accountsAsync.valueOrNull ?? [])
        .where((a) => a.isActive && a.type == AccountType.asset)
        .toList();

    final totalContrib = _schedule.fold<double>(
      0,
      (s, r) => s + r.contribution,
    );
    final totalGrowth = _schedule.fold<double>(0, (s, r) => s + r.growth);
    final increasePct = _parse(_increaseCtrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inputs',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    _Field(
                      label: 'Account',
                      child: SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String?>(
                          value: _accountId,
                          isExpanded: true,
                          decoration: _decoration(colors),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Custom'),
                            ),
                            ...accounts.map(
                              (a) => DropdownMenuItem<String?>(
                                value: a.id,
                                child: Text(
                                  a.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (id) => _onAccountChanged(id, balances),
                        ),
                      ),
                    ),
                    _Field(
                      label: 'Starting balance',
                      child: SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _balanceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                          ],
                          decoration: _decoration(colors, hint: '0.00'),
                        ),
                      ),
                    ),
                    _Field(
                      label: 'Start month',
                      child: SizedBox(
                        width: 140,
                        child: OutlinedButton(
                          onPressed: _pickStartDate,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            side: BorderSide(color: colors.border),
                          ),
                          child: Text(
                            '${_monthName(_startDate.month)} ${_startDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    _Field(
                      label: 'Annual return %',
                      child: SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _rateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _decoration(colors, hint: '7'),
                        ),
                      ),
                    ),
                    _Field(
                      label: 'Monthly savings',
                      child: SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _contribCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _decoration(colors, hint: '0.00'),
                        ),
                      ),
                    ),
                    _Field(
                      label: 'Extra / month',
                      child: SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _extraCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _decoration(colors, hint: '0'),
                        ),
                      ),
                    ),
                    _Field(
                      label: 'Months to project',
                      child: SizedBox(
                        width: 130,
                        child: TextField(
                          controller: _monthsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _decoration(colors, hint: '120'),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _calculate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            child: const Text('Calculate'),
                          ),
                          const SizedBox(width: 16),
                          Switch(
                            value: _showBreakdown,
                            activeThumbColor: colors.primary,
                            onChanged: (v) =>
                                setState(() => _showBreakdown = v),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Show contrib / growth',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Advanced
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showAdvanced
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showAdvanced ? 'Hide advanced' : 'Advanced',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        _Field(
                          label: 'Contrib increase %',
                          child: SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _increaseCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _decoration(colors, hint: 'optional'),
                            ),
                          ),
                        ),
                        _Field(
                          label: 'Every (months)',
                          child: SizedBox(
                            width: 120,
                            child: DropdownButtonFormField<int>(
                              value: _increaseEveryMonths,
                              isExpanded: true,
                              decoration: _decoration(colors),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1')),
                                DropdownMenuItem(value: 3, child: Text('3')),
                                DropdownMenuItem(value: 6, child: Text('6')),
                                DropdownMenuItem(value: 12, child: Text('12')),
                                DropdownMenuItem(value: 24, child: Text('24')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _increaseEveryMonths = v);
                                }
                              },
                            ),
                          ),
                        ),
                        _Field(
                          label: 'Increase on',
                          child: SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<bool>(
                              value: _increaseOnAnniversary,
                              isExpanded: true,
                              decoration: _decoration(colors),
                              items: const [
                                DropdownMenuItem(
                                  value: true,
                                  child: Text(
                                    'Start anniversary',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: false,
                                  child: Text(
                                    'Calendar (Jan…)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _increaseOnAnniversary = v);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: _showAdvanced
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: colors.dangerColor, fontSize: 13),
                  ),
                ],
                if (_schedule.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'After ${_schedule.length} months · '
                    'ending ${money(_schedule.last.balance)} · '
                    'contributed ${money(totalContrib)} · '
                    'growth ${money(totalGrowth)} · '
                    '${_monthName(_schedule.last.date.month)} ${_schedule.last.date.year}'
                    '${increasePct != null && increasePct > 0 ? ' · contrib +${_fmtPct(increasePct)}% / $_increaseEveryMonths mo (${_increaseOnAnniversary ? 'anniversary' : 'calendar'})' : ''}',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: _schedule.isEmpty
              ? Center(
                  child: Text(
                    'Enter inputs and calculate to see monthly balances.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final minCol = _showBreakdown ? 280.0 : 160.0;
                    final perRow = (constraints.maxWidth / minCol)
                        .floor()
                        .clamp(1, 8);

                    final byYear = <int, List<_GrowthRow>>{};
                    for (final row in _schedule) {
                      byYear.putIfAbsent(row.date.year, () => []).add(row);
                    }
                    final years = byYear.keys.toList()..sort();

                    final yearChunks = <List<int>>[];
                    for (var i = 0; i < years.length; i += perRow) {
                      yearChunks.add(
                        years.sublist(i, (i + perRow).clamp(0, years.length)),
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final chunk in yearChunks) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final y in chunk)
                                  Expanded(
                                    child: _YearColumn(
                                      year: y,
                                      rows: byYear[y]!,
                                      money: money,
                                      showBreakdown: _showBreakdown,
                                    ),
                                  ),
                                for (var i = chunk.length; i < perRow; i++)
                                  const Expanded(child: SizedBox()),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
          child: Row(
            children: [
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _schedule.isEmpty ? null : _exportCsv,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export CSV'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtPct(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  InputDecoration _decoration(AppColors colors, {String? hint}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  String _monthName(int m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[m - 1];
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;

  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _YearColumn extends StatelessWidget {
  final int year;
  final List<_GrowthRow> rows;
  final String Function(double) money;
  final bool showBreakdown;

  const _YearColumn({
    required this.year,
    required this.rows,
    required this.money,
    required this.showBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$year',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (showBreakdown)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const SizedBox(width: 32),
                    Expanded(
                      child: Text(
                        'Balance',
                        softWrap: false,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Contrib',
                        softWrap: false,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Growth',
                        softWrap: false,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        _shortMonth(r.date.month),
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (!showBreakdown)
                      Expanded(
                        child: Text(
                          money(r.balance),
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: Text(
                          money(r.balance),
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          money(r.contribution),
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          maxLines: 1,
                          style: TextStyle(fontSize: 12, color: colors.primary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          money(r.growth),
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.successColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _shortMonth(int m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[m - 1];
  }
}
