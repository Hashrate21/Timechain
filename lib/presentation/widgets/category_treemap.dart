import 'dart:math' as math;

import 'package:flutter/material.dart';

class TreemapItem {
  final String id;
  final String label;
  final double value;
  final String valueLabel;
  final Color color;

  const TreemapItem({
    required this.id,
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.color,
  });
}

class CategoryTreemap extends StatelessWidget {
  final List<TreemapItem> items;
  final String? selectedId;
  final String? hoveredId;
  final ValueChanged<String?> onHover;
  final ValueChanged<String> onTap;
  final double height;

  const CategoryTreemap({
    super.key,
    required this.items,
    required this.selectedId,
    required this.hoveredId,
    required this.onHover,
    required this.onTap,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final positive = items.where((i) => i.value > 0).toList();
    if (positive.isEmpty) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: const Center(
          child: Text('No treemap items', style: TextStyle(fontSize: 12)),
        ),
      );
    }

    final total = positive.fold<double>(0, (s, i) => s + i.value);
    final sorted = List<TreemapItem>.from(positive)
      ..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) {
          width = MediaQuery.sizeOf(context).width;
        }
        // Never use infinite / zero height from parent
        final h = height;

        final rects = _squarify(
          items: sorted,
          total: total,
          rect: Rect.fromLTWH(0, 0, width, h),
        );

        // Debug once — remove after it works
        // ignore: avoid_print
        // print(
        //   'TREEMAP w=$width h=$h items=${sorted.length} total=$total rects=${rects.length}',
        // );

        if (rects.isEmpty) {
          // Fallback: simple proportional bars so you always see something
          return SizedBox(
            height: h,
            width: width,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in sorted)
                  Expanded(
                    flex: math.max(1, (item.value / total * 1000).round()),
                    child: Padding(
                      padding: const EdgeInsets.all(1.5),
                      child: ColoredBox(color: item.color),
                    ),
                  ),
              ],
            ),
          );
        }

        return SizedBox(
          height: h,
          width: width,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final r in rects)
                Positioned(
                  left: r.left,
                  top: r.top,
                  width: math.max(1, r.width),
                  height: math.max(1, r.height),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => onHover(r.item.id),
                    onExit: (_) => onHover(null),
                    child: GestureDetector(
                      onTap: () => onTap(r.item.id),
                      child: Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          decoration: BoxDecoration(
                            color: _tileColor(r.item),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(6),
                          alignment: Alignment.topLeft,
                          child: r.width > 48 && r.height > 32
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.topLeft,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _OutlinedText(
                                        text: r.item.label,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        tileColor: r.item.color,
                                      ),
                                      const SizedBox(height: 2),
                                      _OutlinedText(
                                        text: r.item.valueLabel,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        strokeWidth: 2.0,
                                        tileColor: r.item.color,
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _tileColor(TreemapItem item) {
    if (selectedId == null) {
      if (hoveredId == null || hoveredId == item.id) return item.color;
      return item.color.withValues(alpha: 0.35);
    }
    if (selectedId == item.id) return item.color;
    return item.color.withValues(alpha: 0.28);
  }

  List<_TileRect> _squarify({
    required List<TreemapItem> items,
    required double total,
    required Rect rect,
  }) {
    final result = <_TileRect>[];
    if (items.isEmpty || total <= 0 || rect.width <= 0 || rect.height <= 0) {
      return result;
    }

    var remaining = List<TreemapItem>.from(items);
    var remainingTotal = total;
    var current = rect;

    while (remaining.isNotEmpty && remainingTotal > 0) {
      final vertical = current.width >= current.height;
      final side = vertical ? current.height : current.width;
      if (side <= 0 || current.width <= 0 || current.height <= 0) break;

      final row = <TreemapItem>[];
      double rowValue = 0;
      double bestWorst = double.infinity;

      while (remaining.isNotEmpty) {
        final candidate = remaining.first;
        final newRowValue = rowValue + candidate.value;
        final areaScale = (current.width * current.height) / remainingTotal;
        final newWorst = _worstAspect(
          row: [...row, candidate],
          rowValue: newRowValue,
          side: side,
          areaScale: areaScale,
        );

        if (row.isNotEmpty && newWorst > bestWorst) break;

        row.add(candidate);
        rowValue = newRowValue;
        bestWorst = newWorst;
        remaining = remaining.sublist(1);
      }

      if (row.isEmpty || rowValue <= 0) break;

      final areaScale = (current.width * current.height) / remainingTotal;
      final rowArea = rowValue * areaScale;

      if (vertical) {
        final rowWidth = (rowArea / current.height).clamp(0.0, current.width);
        double y = current.top;
        for (final item in row) {
          final h = (item.value / rowValue) * current.height;
          result.add(
            _TileRect(
              item: item,
              left: current.left,
              top: y,
              width: rowWidth,
              height: h,
            ),
          );
          y += h;
        }
        current = Rect.fromLTWH(
          current.left + rowWidth,
          current.top,
          math.max(0, current.width - rowWidth),
          current.height,
        );
      } else {
        final rowHeight = (rowArea / current.width).clamp(0.0, current.height);
        double x = current.left;
        for (final item in row) {
          final w = (item.value / rowValue) * current.width;
          result.add(
            _TileRect(
              item: item,
              left: x,
              top: current.top,
              width: w,
              height: rowHeight,
            ),
          );
          x += w;
        }
        current = Rect.fromLTWH(
          current.left,
          current.top + rowHeight,
          current.width,
          math.max(0, current.height - rowHeight),
        );
      }

      remainingTotal -= rowValue;
    }

    return result;
  }

  double _worstAspect({
    required List<TreemapItem> row,
    required double rowValue,
    required double side,
    required double areaScale,
  }) {
    if (rowValue <= 0 || side <= 0 || areaScale <= 0) return double.infinity;

    final rowArea = rowValue * areaScale;
    final other = rowArea / side;
    if (other <= 0) return double.infinity;

    double worst = 0;
    for (final item in row) {
      final itemArea = item.value * areaScale;
      final a = itemArea / other;
      if (a <= 0) continue;
      final aspect = math.max(other / a, a / other);
      if (aspect > worst) worst = aspect;
    }
    return worst;
  }
}

class _TileRect {
  final TreemapItem item;
  final double left;
  final double top;
  final double width;
  final double height;

  _TileRect({
    required this.item,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

class _OutlinedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final double strokeWidth;
  final Color tileColor;

  const _OutlinedText({
    required this.text,
    required this.fontSize,
    required this.tileColor,
    this.fontWeight = FontWeight.w700,
    this.strokeWidth = 2.5,
  });

  static Color _onTile(Color bg) {
    return bg.computeLuminance() > 0.55
        ? const Color(0xFF0F172A)
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final fg = _onTile(tileColor);
    final stroke = fg == Colors.white
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.7);

    return Stack(
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = stroke,
          ),
        ),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: fg,
          ),
        ),
      ],
    );
  }
}
