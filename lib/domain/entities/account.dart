import 'package:equatable/equatable.dart';

enum AccountType { asset, liability, untracked }

class Account extends Equatable {
  /// Stable system id — never change.
  static const untrackedId = 'acc_untracked';
  static const defaultUntrackedName = 'Untracked';

  final String id;
  final String name;
  final AccountType type;
  final double startingBalance;
  final String currency;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
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

  bool get isUntracked => type == AccountType.untracked || id == untrackedId;

  static String defaultIconFor(AccountType type) {
    switch (type) {
      case AccountType.liability:
        return 'credit_card';
      case AccountType.untracked:
        return 'public_off'; // or 'open_in_new' — add to AccountIcons if needed
      case AccountType.asset:
        return 'account_balance';
    }
  }

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? startingBalance,
    String? currency,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    String? iconKey,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      startingBalance: startingBalance ?? this.startingBalance,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      iconKey: iconKey ?? this.iconKey,
    );
  }

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
