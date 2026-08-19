import 'package:flutter/material.dart';

class CategoryColor {
  final Color start;
  final Color? end;

  const CategoryColor({required this.start, this.end});

  bool get isGradient => end != null;

  static CategoryColor parse(
    String raw, {
    Color fallback = const Color(0xFF3B82F6),
  }) {
    try {
      if (raw.contains('|')) {
        final parts = raw.split('|');
        return CategoryColor(
          start: _hex(parts[0].trim()),
          end: _hex(parts[1].trim()),
        );
      }
      return CategoryColor(start: _hex(raw.trim()));
    } catch (_) {
      return CategoryColor(start: fallback);
    }
  }

  static Color _hex(String s) {
    var h = s.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  BoxDecoration decoration({BoxShape shape = BoxShape.circle}) {
    if (isGradient) {
      return BoxDecoration(
        shape: shape,
        gradient: LinearGradient(
          colors: [start, end!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      );
    }
    return BoxDecoration(color: start, shape: shape);
  }
}
