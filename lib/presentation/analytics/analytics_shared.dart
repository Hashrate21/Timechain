import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/category_color.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/actual_transaction.dart';
import '../../domain/entities/projected_transaction.dart';

// ─── enums ───────────────────────────────────────────────────────────

enum CategoryView { share, treemap, ranked }

enum AnalyticsTab { budget, activity, comparison }

// ─── models ──────────────────────────────────────────────────────────

class Segment {
  final String id;
  final String name;
  final double amount;
  final Color color;

  Segment({
    required this.id,
    required this.name,
    required this.amount,
    required this.color,
  });
}

class BudgetRow {
  final String id;
  final String name;
  final double spent;
  final double budget;
  final CategoryColor catColor;

  BudgetRow({
    required this.id,
    required this.name,
    required this.spent,
    required this.budget,
    required this.catColor,
  });
}

class MonthCompare {
  final String label;
  final double projected;
  final double actual;

  MonthCompare({
    required this.label,
    required this.projected,
    required this.actual,
  });
}

class CategoryTrend {
  final String id;
  final String name;
  final Color color;
  final List<double> monthly;

  CategoryTrend({
    required this.id,
    required this.name,
    required this.color,
    required this.monthly,
  });
}

class CombinedRow {
  final String id;
  final String name;
  final double projected;
  final double actual;
  final double budget;
  final Color color;

  CombinedRow({
    required this.id,
    required this.name,
    required this.projected,
    required this.actual,
    required this.budget,
    required this.color,
  });
}

class FvMonth {
  final String label;
  final double fixed;
  final double variable;
  double get total => fixed + variable;

  const FvMonth({
    required this.label,
    required this.fixed,
    required this.variable,
  });
}

class DescAgg {
  final String label;
  final double amount;
  const DescAgg({required this.label, required this.amount});
}

class DescSlice {
  final String id;
  final String label;
  final double amount;
  final Color color;
  final List<DescSlice> otherParts;

  const DescSlice({
    required this.id,
    required this.label,
    required this.amount,
    required this.color,
    this.otherParts = const [],
  });
}

class DetailCatOption {
  final String id;
  final String name;
  final double total;
  final int distinctCount;
  final int txCount;

  const DetailCatOption({
    required this.id,
    required this.name,
    required this.total,
    required this.distinctCount,
    required this.txCount,
  });
}

class NetTransferRow {
  final String accountId;
  final String name;
  final bool isUntracked;
  final double inflow;
  final double outflow;
  double get net => inflow - outflow;

  NetTransferRow({
    required this.accountId,
    required this.name,
    required this.isUntracked,
    required this.inflow,
    required this.outflow,
  });
}

// ─── helpers ─────────────────────────────────────────────────────────

String truncate12(String s) {
  final t = s.trim();
  if (t.length <= 12) return t;
  return '${t.substring(0, 11)}…';
}

List<NetTransferRow> buildNetTransfers({
  required List<ActualTransaction> transactions,
  required List<Account> accounts,
  required int year,
  required int month,
}) {
  final start = DateTime(year, month, 1);
  final end = DateTime(year, month + 1, 0);
  final byId = <String, ({double inflow, double outflow})>{};

  for (final t in transactions) {
    if (t.type != TransactionType.transfer) continue;
    final d = DateTime(t.date.year, t.date.month, t.date.day);
    if (d.isBefore(start) || d.isAfter(end)) continue;

    final cur = byId[t.accountId] ?? (inflow: 0.0, outflow: 0.0);
    if (t.amount >= 0) {
      byId[t.accountId] = (inflow: cur.inflow + t.amount, outflow: cur.outflow);
    } else {
      byId[t.accountId] = (
        inflow: cur.inflow,
        outflow: cur.outflow + t.amount.abs(),
      );
    }
  }

  final nameOf = {for (final a in accounts) a.id: a};
  final rows = <NetTransferRow>[];

  for (final e in byId.entries) {
    final acc = nameOf[e.key];
    rows.add(
      NetTransferRow(
        accountId: e.key,
        name: acc?.name ?? 'Unknown',
        isUntracked: acc?.isUntracked ?? false,
        inflow: e.value.inflow,
        outflow: e.value.outflow,
      ),
    );
  }

  rows.sort((a, b) => b.net.abs().compareTo(a.net.abs()));
  return rows;
}

// ─── shared chrome ───────────────────────────────────────────────────

class AnalyticsCard extends StatelessWidget {
  final Widget child;
  const AnalyticsCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class AnalyticsTabBar extends StatelessWidget {
  final AnalyticsTab tab;
  final bool showActivity;
  final bool showComparison;
  final ValueChanged<AnalyticsTab> onChanged;

  const AnalyticsTabBar({
    super.key,
    required this.tab,
    required this.showActivity,
    required this.showComparison,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    Widget chip(String label, AnalyticsTab value) {
      final selected = tab == value;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : colors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('Budget', AnalyticsTab.budget),
        if (showActivity) ...[
          const SizedBox(width: 8),
          chip('Activity', AnalyticsTab.activity),
        ],
        if (showComparison) ...[
          const SizedBox(width: 8),
          chip('Comparison', AnalyticsTab.comparison),
        ],
      ],
    );
  }
}

class ViewToggle extends StatelessWidget {
  final CategoryView view;
  final bool showRanked;
  final ValueChanged<CategoryView> onChanged;

  const ViewToggle({
    super.key,
    required this.view,
    required this.showRanked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: 'Bar',
            selected: view == CategoryView.share,
            onTap: () => onChanged(CategoryView.share),
          ),
          _ToggleChip(
            label: 'Treemap',
            selected: view == CategoryView.treemap,
            onTap: () => onChanged(CategoryView.treemap),
          ),
          if (showRanked)
            _ToggleChip(
              label: 'Ranked',
              selected: view == CategoryView.ranked,
              onTap: () => onChanged(CategoryView.ranked),
            ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class ProportionalBar extends StatelessWidget {
  final List<Segment> segments;
  final double total;
  final String? selectedId;
  final String? hoveredId;
  final String Function(double) money0;
  final ValueChanged<String?> onHover;
  final ValueChanged<String> onTap;

  const ProportionalBar({
    super.key,
    required this.segments,
    required this.total,
    required this.selectedId,
    required this.hoveredId,
    required this.money0,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in segments)
              Expanded(
                flex: () {
                  final f = (s.amount / total * 10000).round();
                  return f < 1 ? 1 : f;
                }(),
                child: Tooltip(
                  message: total > 0
                      ? '${s.name}: ${money0(s.amount)} (${(s.amount / total * 100).round()}%)'
                      : '${s.name}: ${money0(s.amount)}',
                  waitDuration: const Duration(milliseconds: 500),
                  child: MouseRegion(
                    onEnter: (_) => onHover(s.id),
                    onExit: (_) => onHover(null),
                    child: GestureDetector(
                      onTap: () => onTap(s.id),
                      child: ColoredBox(
                        color: () {
                          if (selectedId == null) {
                            if (hoveredId == null || hoveredId == s.id) {
                              return s.color;
                            }
                            return s.color.withValues(alpha: 0.35);
                          }
                          if (selectedId == s.id) return s.color;
                          return s.color.withValues(alpha: 0.28);
                        }(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SegmentLegend extends StatelessWidget {
  final List<Segment> segments;
  final double total;
  final String? selectedId;
  final String Function(double) money0;
  final ValueChanged<String> onTap;

  const SegmentLegend({
    super.key,
    required this.segments,
    required this.total,
    required this.selectedId,
    required this.money0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final s in segments)
          InkWell(
            onTap: () => onTap(s.id),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  total > 0
                      ? '${s.name}  ${money0(s.amount)}  (${(s.amount / total * 100).round()}%)'
                      : '${s.name}  ${money0(s.amount)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selectedId == s.id
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: selectedId == null || selectedId == s.id
                        ? null
                        : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class RankedSpendBars extends StatelessWidget {
  final List<Segment> segments;
  final double total;
  final String? selectedId;
  final String? hoveredId;
  final String Function(double) money0;
  final bool isDark;
  final ValueChanged<String?> onHover;
  final ValueChanged<String> onTap;

  const RankedSpendBars({
    super.key,
    required this.segments,
    required this.total,
    required this.selectedId,
    required this.hoveredId,
    required this.money0,
    required this.isDark,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (segments.isEmpty) return const SizedBox.shrink();

    double maxY = 0;
    for (final s in segments) {
      if (s.amount > maxY) maxY = s.amount;
    }
    if (maxY <= 0) maxY = 100;
    maxY *= 1.18;

    final barWidth = segments.length <= 5
        ? 100.0
        : segments.length <= 8
        ? 80.0
        : segments.length <= 12
        ? 50.0
        : 30.0;

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        alignment: BarChartAlignment.spaceEvenly,
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= segments.length) {
                return null;
              }
              final s = segments[groupIndex];
              final pct = total > 0 ? (s.amount / total * 100).round() : 0;
              return BarTooltipItem(
                '${s.name}\n${money0(s.amount)}  ($pct%)',
                TextStyle(
                  color: s.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
          touchCallback: (event, response) {
            if (response == null || response.spot == null) {
              if (event is FlPointerExitEvent || event is FlTapUpEvent) {
                onHover(null);
              }
              return;
            }
            final idx = response.spot!.touchedBarGroupIndex;
            if (idx < 0 || idx >= segments.length) return;
            final id = segments[idx].id;
            if (event is FlPointerHoverEvent ||
                event is FlLongPressMoveUpdate) {
              onHover(id);
            }
            if (event is FlTapUpEvent) {
              onTap(id);
            }
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value >= meta.max) {
                  return const SizedBox.shrink();
                }
                final label = value.abs() >= 1000
                    ? '${(value / 1000).toStringAsFixed(0)}k'
                    : value.toInt().toString();
                return Text(
                  label,
                  style: TextStyle(fontSize: 10, color: colors.textSecondary),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= segments.length) {
                  return const SizedBox.shrink();
                }
                final name = segments[i].name;
                final short = name.length <= 8
                    ? name
                    : '${name.substring(0, 7)}…';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    short,
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.textSecondary,
                      fontWeight: selectedId == segments[i].id
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 0; i < segments.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: segments[i].amount,
                  width: barWidth,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  color: () {
                    final s = segments[i];
                    if (selectedId == null) {
                      if (hoveredId == null || hoveredId == s.id) {
                        return s.color;
                      }
                      return s.color.withValues(alpha: 0.35);
                    }
                    if (selectedId == s.id) return s.color;
                    return s.color.withValues(alpha: 0.28);
                  }(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class DescRankedBars extends StatelessWidget {
  final List<DescSlice> slices;
  final double total;
  final String? selectedId;
  final String? hoveredId;
  final String Function(double) money0;
  final ValueChanged<String?> onHover;
  final ValueChanged<String> onTap;

  const DescRankedBars({
    super.key,
    required this.slices,
    required this.total,
    required this.selectedId,
    required this.hoveredId,
    required this.money0,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final maxAmt = slices
        .map((s) => s.amount)
        .fold<double>(0, (a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    return Column(
      children: [
        for (final s in slices)
          Tooltip(
            waitDuration: const Duration(milliseconds: 500),
            message: s.id == '__other__' && s.otherParts.isNotEmpty
                ? s.otherParts
                      .map((p) => '${p.label}: ${money0(p.amount)}')
                      .join('\n')
                : '${s.label}\n${money0(s.amount)}'
                      '${total > 0 ? ' (${(s.amount / total * 100).round()}%)' : ''}',
            child: MouseRegion(
              onEnter: (_) => onHover(s.id),
              onExit: (_) => onHover(null),
              child: InkWell(
                onTap: () => onTap(s.id),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 88,
                        child: Text(
                          truncate12(s.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selectedId == s.id
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selectedId == null || selectedId == s.id
                                ? null
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final barW =
                                (s.amount / maxAmt) * constraints.maxWidth;
                            final dimmed =
                                (selectedId != null && selectedId != s.id) ||
                                (hoveredId != null &&
                                    selectedId == null &&
                                    hoveredId != s.id);
                            return Stack(
                              children: [
                                Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: colors.border.withValues(
                                      alpha: 0.35,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Container(
                                  height: 16,
                                  width: barW,
                                  decoration: BoxDecoration(
                                    color: dimmed
                                        ? s.color.withValues(alpha: 0.3)
                                        : s.color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: Text(
                          total > 0
                              ? '${money0(s.amount)} ${(s.amount / total * 100).round()}%'
                              : money0(s.amount),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selectedId == null || selectedId == s.id
                                ? null
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class CategoryTrendsChart extends StatelessWidget {
  final List<String> monthLabels;
  final List<CategoryTrend> trends;
  final bool isDark;

  const CategoryTrendsChart({
    super.key,
    required this.monthLabels,
    required this.trends,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (trends.isEmpty || monthLabels.isEmpty) {
      return const SizedBox.shrink();
    }
    double maxY = 0;
    for (final t in trends) {
      for (final v in t.monthly) {
        if (v > maxY) maxY = v;
      }
    }
    if (maxY <= 0) maxY = 100;
    maxY *= 1.15;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (monthLabels.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((s) {
                final idx = s.barIndex;
                if (idx < 0 || idx >= trends.length) return null;
                final trend = trends[idx];
                return LineTooltipItem(
                  '${trend.name}\n${s.y.toStringAsFixed(0)}',
                  TextStyle(
                    color: trend.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value >= meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(fontSize: 10, color: colors.textSecondary),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= monthLabels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    monthLabels[i],
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          for (int i = 0; i < trends.length; i++)
            LineChartBarData(
              spots: [
                for (int m = 0; m < trends[i].monthly.length; m++)
                  FlSpot(m.toDouble(), trends[i].monthly[m]),
              ],
              isCurved: true,
              color: trends[i].color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
        ],
      ),
    );
  }
}

class ProjectedActualChart extends StatelessWidget {
  final List<MonthCompare> months;
  final bool isDark;

  const ProjectedActualChart({
    super.key,
    required this.months,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    double maxY = 0;
    for (final m in months) {
      if (m.projected > maxY) maxY = m.projected;
      if (m.actual > maxY) maxY = m.actual;
    }
    if (maxY <= 0) maxY = 100;
    maxY *= 1.15;
    const actualColor = Color(0xFFF59E0B);

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final m = months[group.x.toInt()];
              final isProjected = rodIndex == 0;
              final value = isProjected ? m.projected : m.actual;
              final name = isProjected ? 'Projected' : 'Actual';
              return BarTooltipItem(
                '$name\n${value.toStringAsFixed(0)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value >= meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(fontSize: 10, color: colors.textSecondary),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) {
                  return const SizedBox.shrink();
                }
                final parts = months[i].label.split('-');
                final mm = parts.length > 1 ? parts[1] : months[i].label;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    mm,
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: months[i].projected,
                  color: colors.primary,
                  width: 50,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                BarChartRodData(
                  toY: months[i].actual,
                  color: actualColor,
                  width: 50,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class FvThisMonthPanel extends StatelessWidget {
  final double fixed;
  final double variable;
  final String Function(double) money;
  final String Function(double) money0;

  const FvThisMonthPanel({
    super.key,
    required this.fixed,
    required this.variable,
    required this.money,
    required this.money0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final total = fixed + variable;
    final fFrac = total > 0 ? (fixed / total).clamp(0.0, 1.0) : 0.0;
    final vFrac = (1.0 - fFrac).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This month',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (total <= 0)
          Text(
            'No projected expenses this month',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          )
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  if (fFrac > 0)
                    Expanded(
                      flex: (fFrac * 1000).round().clamp(1, 1000),
                      child: Container(color: colors.primary),
                    ),
                  if (vFrac > 0)
                    Expanded(
                      flex: (vFrac * 1000).round().clamp(1, 1000),
                      child: Container(
                        color: colors.warningColor.withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Fixed ${(fFrac * 100).round()}% · Variable ${(vFrac * 100).round()}%',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'F ${money(fixed)}',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          Text(
            'V ${money(variable)}',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Total ${money0(total)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class FvHistoryChart extends StatelessWidget {
  final List<FvMonth> months;
  final bool isDark;
  final String Function(double) money0;

  const FvHistoryChart({
    super.key,
    required this.months,
    required this.isDark,
    required this.money0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    double maxY = 0;
    for (final m in months) {
      if (m.total > maxY) maxY = m.total;
    }
    if (maxY <= 0) maxY = 100;
    maxY *= 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last 6 months',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex < 0 || groupIndex >= months.length) {
                      return null;
                    }
                    final m = months[groupIndex];
                    return BarTooltipItem(
                      '${m.label}\n'
                      'Fixed ${money0(m.fixed)}\n'
                      'Variable ${money0(m.variable)}\n'
                      'Total ${money0(m.total)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value >= meta.max) {
                        return const SizedBox.shrink();
                      }
                      final label = value.abs() >= 1000
                          ? '${(value / 1000).toStringAsFixed(0)}k'
                          : value.toInt().toString();
                      return Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.textSecondary,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= months.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          months[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (int i = 0; i < months.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: months[i].total <= 0 ? 0 : months[i].total,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        rodStackItems: months[i].total <= 0
                            ? const []
                            : [
                                BarChartRodStackItem(
                                  0,
                                  months[i].fixed,
                                  colors.primary,
                                ),
                                BarChartRodStackItem(
                                  months[i].fixed,
                                  months[i].total,
                                  colors.warningColor.withValues(alpha: 0.9),
                                ),
                              ],
                        color: months[i].total <= 0
                            ? colors.border.withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class NetTransfersChart extends StatelessWidget {
  final List<NetTransferRow> rows;
  final String Function(double) money;
  final String Function(double) money0;

  const NetTransfersChart({
    super.key,
    required this.rows,
    required this.money,
    required this.money0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final maxAbs = rows
        .map((r) => r.net.abs())
        .fold<double>(0, (a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    return Column(
      children: [
        for (final r in rows)
          Tooltip(
            waitDuration: const Duration(milliseconds: 500),
            message:
                '${r.name}${r.isUntracked ? ' · untracked' : ''}\n'
                'In  ${money(r.inflow)}\n'
                'Out ${money(r.outflow)}\n'
                'Net ${money(r.net)}',
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      r.isUntracked ? '${r.name} · ext' : r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final mid = w / 2;
                        final barW = (r.net.abs() / maxAbs) * (mid - 4);

                        return SizedBox(
                          height: 22,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                left: mid,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 1,
                                  color: colors.border,
                                ),
                              ),
                              if (r.net < 0)
                                Positioned(
                                  right: mid,
                                  child: Container(
                                    width: barW,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: colors.dangerColor.withValues(
                                        alpha: 0.85,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              if (r.net > 0)
                                Positioned(
                                  left: mid,
                                  child: Container(
                                    width: barW,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: colors.successColor.withValues(
                                        alpha: 0.85,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: Text(
                      money0(r.net),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: r.net >= 0
                            ? colors.successColor
                            : colors.dangerColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
