import 'package:equatable/equatable.dart';

import 'projected_transaction.dart'; // for TransactionType

class ActualTemplate extends Equatable {
  final String id;
  final String name; // picker label
  final String description;
  final double amount;
  final TransactionType type; // income | expense only
  final String categoryId;
  final String accountId;
  final String? notes;
  final int sortOrder;
  final DateTime createdAt;

  const ActualTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.notes,
    this.sortOrder = 0,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    amount,
    type,
    categoryId,
    accountId,
  ];
}
