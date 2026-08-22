import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/app_settings.dart';
import '../providers/app_providers.dart';

class _ScheduleRow {
  final DateTime date;
  final double payment;
  final double principal;
  final double interest;
  final double balance;

  const _ScheduleRow({
    required this.date,
    required this.payment,
    required this.principal,
    required this.interest,
    required this.balance,
  });
}

class DebtRepaymentCalculator extends ConsumerStatefulWidget {
  const DebtRepaymentCalculator({super.key});

  @override
  ConsumerState<DebtRepaymentCalculator> createState() =>
      _DebtRepaymentCalculatorState();
}

class _DebtRepaymentCalculatorState
    extends ConsumerState<DebtRepaymentCalculator> {
  String? _accountId;

  final _balanceCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '0');
  final _paymentCtrl = TextEditingController();
  final _extraCtrl = TextEditingController(text: '0');
  final _termCtrl = TextEditingController();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  List<_ScheduleRow> _schedule = [];
  String? _error;
  bool _showBreakdown = false;
  bool _loaded = false;

  @override
  void dispose() {
    _balanceCtrl.dispose();
    _rateCtrl.dispose();
    _paymentCtrl.dispose();
    _extraCtrl.dispose();
    _termCtrl.dispose();
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

  Future<void> _restorePreset({String? accountId}) async {
    final repo = ref.read(calculatorPresetRepositoryProvider);
    final map = await repo.getPreset(calculator: 'debt', accountId: accountId);
    // Fallback to global if per-account missing
    final data =
        map ??
        (accountId != null
            ? await repo.getPreset(calculator: 'debt', accountId: null)
            : null);
    if (!mounted) return;
    if (data == null) return;

    setState(() {
      if (data['apr'] != null) {
        _rateCtrl.text = _numStr(data['apr']);
      }
      if (data['monthly_payment'] != null) {
        _paymentCtrl.text = _numStr(data['monthly_payment']);
      }
      if (data['extra'] != null) {
        _extraCtrl.text = _numStr(data['extra']);
      }
      if (data['term_months'] != null) {
        _termCtrl.text = '${data['term_months']}';
      } else if (accountId != null) {
        // keep term as-is when switching accounts without stored term
      }
      if (data['start_year'] is int && data['start_month'] is int) {
        _startDate = DateTime(
          data['start_year'] as int,
          data['start_month'] as int,
          1,
        );
      }
      if (data['show_breakdown'] is bool) {
        _showBreakdown = data['show_breakdown'] as bool;
      }
      // Custom balance only when no account (account balance comes from live data)
      if (accountId == null && data['balance'] != null) {
        _balanceCtrl.text = _numStr(data['balance']);
      }
    });
  }

  String _numStr(dynamic v) {
    if (v is num) {
      if (v == v.roundToDouble()) return v.toStringAsFixed(0);
      return v.toString();
    }
    return '$v';
  }

  Future<void> _persistPreset() async {
    final repo = ref.read(calculatorPresetRepositoryProvider);
    final payload = <String, dynamic>{
      'apr': _parse(_rateCtrl),
      'monthly_payment': _parse(_paymentCtrl),
      'extra': _parse(_extraCtrl) ?? 0,
      'term_months': int.tryParse(_termCtrl.text.trim()),
      'start_year': _startDate.year,
      'start_month': _startDate.month,
      'show_breakdown': _showBreakdown,
      if (_accountId == null) 'balance': _parse(_balanceCtrl),
      'last_account_id': _accountId,
    };

    // Always update global "last used"
    await repo.savePreset(
      calculator: 'debt',
      accountId: null,
      payload: {...payload, 'balance': _parse(_balanceCtrl)},
    );

    // Per-account slot
    if (_accountId != null) {
      await repo.savePreset(
        calculator: 'debt',
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
        _balanceCtrl.text = bal.abs().toStringAsFixed(2);
      }
    });
    await _restorePreset(accountId: id);
    // Re-apply live balance after preset (account wins)
    if (id != null && mounted) {
      final bal = balances[id] ?? 0;
      setState(() {
        _balanceCtrl.text = bal.abs().toStringAsFixed(2);
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

  double _pow(double base, double exp) => math.pow(base, exp).toDouble();

  Future<void> _calculate() async {
    final balance = _parse(_balanceCtrl);
    final rate = _parse(_rateCtrl) ?? 0;
    final extra = _parse(_extraCtrl) ?? 0;
    var payment = _parse(_paymentCtrl);
    final termMonths = int.tryParse(_termCtrl.text.trim());

    if (balance == null || balance <= 0) {
      setState(() {
        _error = 'Enter a starting balance greater than 0.';
        _schedule = [];
      });
      return;
    }
    if (rate < 0) {
      setState(() {
        _error = 'Interest rate cannot be negative.';
        _schedule = [];
      });
      return;
    }

    final monthlyRate = rate / 100 / 12;

    if ((payment == null || payment <= 0) &&
        termMonths != null &&
        termMonths > 0) {
      if (monthlyRate == 0) {
        payment = balance / termMonths;
      } else {
        final r = monthlyRate;
        final n = termMonths.toDouble();
        payment = balance * r * _pow(1 + r, n) / (_pow(1 + r, n) - 1);
      }
      _paymentCtrl.text = payment.toStringAsFixed(2);
    }

    if (payment == null || payment <= 0) {
      setState(() {
        _error =
            'Enter a monthly payment, or a term (months) to solve for payment.';
        _schedule = [];
      });
      return;
    }

    final totalPayment = payment + extra;
    if (monthlyRate > 0 && totalPayment <= balance * monthlyRate) {
      setState(() {
        _error =
            'Payment is too low to cover interest. Increase payment or extra.';
        _schedule = [];
      });
      return;
    }

    final rows = <_ScheduleRow>[];
    var bal = balance;
    var date = _startDate;
    const maxMonths = 600;

    for (var i = 0; i < maxMonths && bal > 0.005; i++) {
      final interest = monthlyRate == 0 ? 0.0 : bal * monthlyRate;
      var principal = totalPayment - interest;
      if (principal > bal) principal = bal;
      if (principal < 0) principal = 0;
      final actualPayment = principal + interest;
      bal = (bal - principal).clamp(0.0, double.infinity);

      rows.add(
        _ScheduleRow(
          date: date,
          payment: actualPayment,
          principal: principal,
          interest: interest,
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
    buf.writeln('month,year,payment,principal,interest,balance');
    for (final r in _schedule) {
      buf.writeln(
        '${r.date.month},${r.date.year},'
        '${r.payment.toStringAsFixed(2)},'
        '${r.principal.toStringAsFixed(2)},'
        '${r.interest.toStringAsFixed(2)},'
        '${r.balance.toStringAsFixed(2)}',
      );
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final name =
          'debt_schedule_${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}.csv';
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
        .where((a) => a.isActive && a.type == AccountType.liability)
        .toList();

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
                      label: 'APR %',
                      child: SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _rateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _decoration(colors, hint: '0'),
                        ),
                      ),
                    ),
                    _Field(
                      label: 'Monthly payment',
                      child: SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _paymentCtrl,
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
                      label: 'Term (months)',
                      child: SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _termCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _decoration(colors, hint: 'optional'),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                            'Show principal / interest',
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
                    'Payoff in ${_schedule.length} months · '
                    'last payment ${money(_schedule.last.payment)} · '
                    '${_monthName(_schedule.last.date.month)} ${_schedule.last.date.year}',
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
                    'Enter inputs and calculate to see the monthly schedule.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final minCol = _showBreakdown ? 280.0 : 160.0;
                    final perRow = (constraints.maxWidth / minCol)
                        .floor()
                        .clamp(1, 8);

                    final byYear = <int, List<_ScheduleRow>>{};
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
        // Footer export
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
  final List<_ScheduleRow> rows;
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
                        'Payment',
                        softWrap: false,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Principal',
                        softWrap: false,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Interest',
                        softWrap: false,
                        maxLines: 1,
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
                          money(r.payment),
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
                          money(r.payment),
                          softWrap: false,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          money(r.principal),
                          softWrap: false,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.successColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          money(r.interest),
                          softWrap: false,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.warningColor,
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
