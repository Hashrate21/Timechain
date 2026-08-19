import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BudgetPaths {
  static const lastFileName = 'last_budget_path.txt';
  static const legacyDbName = 'budget_v2.db';

  static Future<Directory> documentsDir() async {
    return getApplicationDocumentsDirectory();
  }

  static Future<Directory> budgetsDir() async {
    final docs = await documentsDir();
    final dir = Directory(p.join(docs.path, 'BudgetApp', 'budgets'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> lastPathFile() async {
    final docs = await documentsDir();
    return p.join(docs.path, 'BudgetApp', lastFileName);
  }

  static Future<String?> readLastPath() async {
    try {
      final f = File(await lastPathFile());
      if (!await f.exists()) return null;
      final path = (await f.readAsString()).trim();
      if (path.isEmpty) return null;
      if (await File(path).exists()) return path;
    } catch (_) {}
    return null;
  }

  static Future<void> writeLastPath(String path) async {
    final file = File(await lastPathFile());
    await file.parent.create(recursive: true);
    await file.writeAsString(path);
  }

  static Future<String> legacyPath() async {
    final docs = await documentsDir();
    return p.join(docs.path, legacyDbName);
  }

  /// Prefer last path → legacy budget_v2.db → Default.db in budgets folder
  static Future<String> resolveInitialPath() async {
    final last = await readLastPath();
    if (last != null) return last;

    final legacy = await legacyPath();
    if (await File(legacy).exists()) return legacy;

    final dir = await budgetsDir();
    return p.join(dir.path, 'Default.db');
  }

  static String displayName(String path) {
    return p.basenameWithoutExtension(path);
  }

  static String safeFileName(String name) {
    var s = name.trim();
    if (s.isEmpty) s = 'Budget';
    s = s.replaceAll(RegExp(r'[^\w\s\-]'), '');
    s = s.replaceAll(RegExp(r'\s+'), '_');
    if (s.isEmpty) s = 'Budget';
    return '$s.db';
  }

  static Future<List<String>> listBudgetPaths() async {
    final dir = await budgetsDir();
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.db')) {
        files.add(entity);
      }
    }

    final paths = files.map((f) => f.path).toList();

    final legacy = await legacyPath();
    if (await File(legacy).exists() && !paths.contains(legacy)) {
      paths.insert(0, legacy);
    }

    paths.sort(
      (a, b) => displayName(a)
          .toLowerCase()
          .compareTo(displayName(b).toLowerCase()),
    );
    return paths;
  }

  static Future<String> pathForNewName(String name) async {
    final dir = await budgetsDir();
    return p.join(dir.path, safeFileName(name));
  }
}