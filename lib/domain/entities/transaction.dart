import 'package:equatable/equatable.dart';

enum TransactionType { income, expense }

class Transaction extends Equatable {
  final String id;
  final String name;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final bool isRecurring;
  final String? recurrence; // monthly, weekly, etc.
  final bool isPaid;
  final int sortOrder;

  const Transaction({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.isRecurring = false,
    this.recurrence,
    this.isPaid = false,
    this.sortOrder = 0,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        amount,
        type,
        category,
        date,
        isRecurring,
        recurrence,
        isPaid,
        sortOrder,
      ];
}