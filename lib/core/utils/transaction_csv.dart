class ParsedTxRow {
  final int lineNumber;
  final DateTime? date;
  final String accountRaw;
  final String description;
  final String categoryRaw;
  final String typeRaw;
  final double? amount;
  final String notes;
  final String? error;
  final String? fromAccountRaw;
  final String? toAccountRaw;

  const ParsedTxRow({
    required this.lineNumber,
    this.date,
    this.accountRaw = '',
    this.description = '',
    this.categoryRaw = '',
    this.typeRaw = '',
    this.amount,
    this.notes = '',
    this.error,
    this.fromAccountRaw,
    this.toAccountRaw,
  });

  bool get ok => error == null;
}

class TransactionCsv {
  static List<String> splitLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            sb.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          sb.write(c);
        }
      } else {
        if (c == '"') {
          inQuotes = true;
        } else if (c == ',') {
          result.add(sb.toString());
          sb.clear();
        } else {
          sb.write(c);
        }
      }
    }
    result.add(sb.toString());
    return result;
  }

  /// True when the amount string has more than 2 digits after the decimal.
  /// Uses the raw string so floating-point noise does not hide typos.
  static bool hasMoreThanTwoDecimals(String raw) {
    final s = raw.trim().replaceAll(',', '');
    final dot = s.indexOf('.');
    if (dot < 0) return false;
    final decimals = s.length - dot - 1;
    return decimals > 2;
  }

  /// Accepts export CSV or tab-separated paste from Excel.
  static List<ParsedTxRow> parse(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return [];

    // Normalize tabs → commas for simple TSV pastes (no commas inside cells)
    final useTabs = text.contains('\t') && !text.contains(',');
    if (useTabs) {
      text = text.split('\n').map((l) => l.split('\t').join(',')).join('\n');
    }

    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];

    var start = 0;
    final first = splitLine(lines.first).map((s) => s.toLowerCase()).toList();
    if (first.contains('date') && first.contains('amount')) {
      start = 1;
    }

    final rows = <ParsedTxRow>[];
    for (var i = start; i < lines.length; i++) {
      final cols = splitLine(lines[i]);
      final lineNumber = i + 1;
      if (cols.length < 6) {
        rows.add(ParsedTxRow(
          lineNumber: lineNumber,
          error: 'Need at least 6 columns',
        ));
        continue;
      }

      final dateStr = cols[0].trim();
      final account = cols[1].trim();
      final description = cols[2].trim();
      final category = cols[3].trim();
      final typeRaw = cols[4].trim().toLowerCase();
      final amountStr = cols[5].trim().replaceAll(',', '');
      final notes = cols.length > 6 ? cols[6].trim() : '';

      final date = DateTime.tryParse(dateStr);
      final amount = double.tryParse(amountStr);

      String? error;
      if (date == null) error = 'Bad date (use yyyy-MM-dd)';
      if (amount == null || amount < 0) {
        error = error ?? 'Bad amount';
      } else if (hasMoreThanTwoDecimals(amountStr)) {
        error = error ?? 'Amount max 2 decimal places';
      }
      if (typeRaw != 'income' &&
          typeRaw != 'expense' &&
          typeRaw != 'transfer') {
        error = error ?? 'Type must be income, expense, or transfer';
      }
      if (description.isEmpty) error = error ?? 'Missing description';

      String? fromA;
      String? toA;
      if (typeRaw == 'transfer') {
        final parts = account.split('→').map((s) => s.trim()).toList();
        if (parts.length != 2) {
          error = error ?? 'Transfer account must be "From → To"';
        } else {
          fromA = parts[0];
          toA = parts[1];
        }
      }

      rows.add(ParsedTxRow(
        lineNumber: lineNumber,
        date: date,
        accountRaw: account,
        description: description,
        categoryRaw: category,
        typeRaw: typeRaw,
        amount: amount,
        notes: notes,
        error: error,
        fromAccountRaw: fromA,
        toAccountRaw: toA,
      ));
    }
    return rows;
  }
}