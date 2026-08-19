import 'package:equatable/equatable.dart';

class CategoryBudget extends Equatable {
  final String id;
  final String categoryId;
  final String yearMonth; // e.g. "2026-08"
  final double budgetAmount;
  final DateTime createdAt;

  const CategoryBudget({
    required this.id,
    required this.categoryId,
    required this.yearMonth,
    required this.budgetAmount,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, categoryId, yearMonth, budgetAmount, createdAt];
}