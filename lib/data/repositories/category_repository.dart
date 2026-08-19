import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../domain/entities/category.dart';

class CategoryRepository {
  final DatabaseHelper dbHelper;
  final _uuid = const Uuid();

  CategoryRepository(this.dbHelper);

  Future<List<Category>> getAll() async {
    final db = await dbHelper.database;
    final maps = await db.query('categories', orderBy: 'sort_order ASC, name ASC');

    return maps.map((map) {
      return Category(
        id: map['id'] as String,
        name: map['name'] as String,
        color: map['color'] as String,
        icon: map['icon'] as String?,
        isIncome: (map['is_income'] as int) == 1,
        isTransfer: (map['is_transfer'] as int) == 1,
        sortOrder: map['sort_order'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
    }).toList();
  }

  Future<void> insert(Category category) async {
    final db = await dbHelper.database;
    await db.insert('categories', {
      'id': category.id,
      'name': category.name,
      'color': category.color,
      'icon': category.icon,
      'is_income': category.isIncome ? 1 : 0,
      'is_transfer': category.isTransfer ? 1 : 0,
      'sort_order': category.sortOrder,
      'created_at': category.createdAt.toIso8601String(),
    });
  }

  Future<void> update(Category category) async {
    final db = await dbHelper.database;
    await db.update(
      'categories',
      {
        'name': category.name,
        'color': category.color,
        'icon': category.icon,
        'is_income': category.isIncome ? 1 : 0,
        'is_transfer': category.isTransfer ? 1 : 0,
        'sort_order': category.sortOrder,
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await dbHelper.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<Category> create({
    required String name,
    required String color,
    bool isIncome = false,
    bool isTransfer = false,
  }) async {
    final category = Category(
      id: _uuid.v4(),
      name: name,
      color: color,
      isIncome: isIncome,
      isTransfer: isTransfer,
      createdAt: DateTime.now(),
    );
    await insert(category);
    return category;
  }
}