import 'package:equatable/equatable.dart';

enum AccountType { asset, liability }

class Account extends Equatable {
  final String id;
  final String name;
  final AccountType type;
  final double startingBalance;
  final String currency;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  /// Material icon key, e.g. 'account_balance', 'credit_card'
  final String iconKey;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.startingBalance = 0.0,
    this.currency = '\$',
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    this.iconKey = 'account_balance',
  });

  static String defaultIconFor(AccountType type) =>
      type == AccountType.asset ? 'account_balance' : 'credit_card';

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        startingBalance,
        currency,
        isActive,
        sortOrder,
        createdAt,
        iconKey,
      ];
}