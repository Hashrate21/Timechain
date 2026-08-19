import 'package:equatable/equatable.dart';

class BudgetSettings extends Equatable {
  final double startingBalance;
  final double safetyBuffer;
  final DateTime? projectionEndDate;
  final String currencySymbol;

  const BudgetSettings({
    this.startingBalance = 0.0,
    this.safetyBuffer = 0.0,
    this.projectionEndDate,
    this.currencySymbol = '\$',
  });

  @override
  List<Object?> get props => [
        startingBalance,
        safetyBuffer,
        projectionEndDate,
        currencySymbol,
      ];
}