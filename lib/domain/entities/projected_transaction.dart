import 'package:equatable/equatable.dart';

enum TransactionType { income, expense, transfer }

enum RecurrenceType {
  none,
  weekly,
  biweekly,
  monthly,
  twiceMonthly,
  quarterly,
  yearly,
}

class ProjectedTransaction extends Equatable {
  final String id;
  final String name;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String? accountId;
  final DateTime startDate;
  final RecurrenceType recurrence;
  final int? recurrenceDay;      // day of month (1-31)
  final int? recurrenceDay2;     // second day for twiceMonthly
  final int? recurrenceWeekday;  // 0 = Monday ... 6 = Sunday
  final DateTime? recurrenceEnd;
  final bool isPaid;
  final String? notes;
  final int sortOrder;
  final DateTime createdAt;

  const ProjectedTransaction({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.categoryId,
    this.accountId,
    required this.startDate,
    this.recurrence = RecurrenceType.none,
    this.recurrenceDay,
    this.recurrenceDay2,
    this.recurrenceWeekday,
    this.recurrenceEnd,
    this.isPaid = false,
    this.notes,
    this.sortOrder = 0,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        amount,
        type,
        categoryId,
        accountId,
        startDate,
        recurrence,
        recurrenceDay,
        recurrenceDay2,
        recurrenceWeekday,
        recurrenceEnd,
        isPaid,
        notes,
        sortOrder,
        createdAt,
      ];
}