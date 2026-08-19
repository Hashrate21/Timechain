import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String id;
  final String name;
  final String color;
  final String? icon;
  final bool isIncome;
  final bool isTransfer;
  final int sortOrder;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.name,
    required this.color,
    this.icon,
    this.isIncome = false,
    this.isTransfer = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        color,
        icon,
        isIncome,
        isTransfer,
        sortOrder,
        createdAt,
      ];
}