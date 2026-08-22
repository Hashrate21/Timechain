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

/// Locked vs flexible plan amount (not the same as recurrence).
enum CostNature { fixed, variable }

class ProjectedTransaction extends Equatable {
  final String id;
  final String name;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String? accountId;
  final DateTime startDate;
  final RecurrenceType recurrence;
  final int? recurrenceDay; // day of month (1-31)
  final int? recurrenceDay2; // second day for twiceMonthly
  final int? recurrenceWeekday; // 0 = Monday ... 6 = Sunday
  final DateTime? recurrenceEnd;
  final bool isPaid;
  final String? notes;
  final int sortOrder;
  final DateTime createdAt;
  final CostNature costNature;

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
    this.costNature = CostNature.variable,
  });

  ProjectedTransaction copyWith({
    String? id,
    String? name,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    DateTime? startDate,
    RecurrenceType? recurrence,
    int? recurrenceDay,
    int? recurrenceDay2,
    int? recurrenceWeekday,
    DateTime? recurrenceEnd,
    bool? isPaid,
    String? notes,
    int? sortOrder,
    DateTime? createdAt,
    CostNature? costNature,
  }) {
    return ProjectedTransaction(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      startDate: startDate ?? this.startDate,
      recurrence: recurrence ?? this.recurrence,
      recurrenceDay: recurrenceDay ?? this.recurrenceDay,
      recurrenceDay2: recurrenceDay2 ?? this.recurrenceDay2,
      recurrenceWeekday: recurrenceWeekday ?? this.recurrenceWeekday,
      recurrenceEnd: recurrenceEnd ?? this.recurrenceEnd,
      isPaid: isPaid ?? this.isPaid,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      costNature: costNature ?? this.costNature,
    );
  }

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
    costNature,
  ];
}
