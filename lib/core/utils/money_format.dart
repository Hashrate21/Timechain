import '../../domain/entities/app_settings.dart';

String formatMoney(
  double amount, {
  required String symbol,
  required bool showSymbol,
  required NegativeFormat negativeFormat,
  int decimals = 2,
}) {
  final absVal = amount.abs();
  final fixed = absVal.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  final formatted =
      parts.length > 1 ? '$whole.${parts[1]}' : whole;

  final core = showSymbol ? '$symbol$formatted' : formatted;

  if (amount < 0) {
    if (negativeFormat == NegativeFormat.parentheses) {
      return '($core)';
    }
    return '-$core';
  }
  return core;
}

String formatMoneyFromSettings(double amount, AppSettings settings) {
  return formatMoney(
    amount,
    symbol: settings.currencySymbol,
    showSymbol: settings.showCurrencySymbol,
    negativeFormat: settings.negativeFormat,
  );
}