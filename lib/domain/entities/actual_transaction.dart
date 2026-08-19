import 'package:equatable/equatable.dart';
import 'projected_transaction.dart'; // for TransactionType

class ActualTransaction extends Equatable {
  final String id;
  final DateTime date;
  final String accountId;
  final String name;
  final String categoryId;
  final double amount;
  final TransactionType type;
  final String? notes;
  final String? transferPairId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ActualTransaction({
    required this.id,
    required this.date,
    required this.accountId,
    required this.name,
    required this.categoryId,
    required this.amount,
    required this.type,
    this.notes,
    this.transferPairId,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        date,
        accountId,
        name,
        categoryId,
        amount,
        type,
        notes,
        transferPairId,
        createdAt,
        updatedAt,
      ];
}