import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/app_settings.dart';
import '../widgets/category_treemap.dart';
import 'analytics_shared.dart';

class BudgetTab extends StatefulWidget {
  final String monthLabel;
  final AppMode appMode;
  final bool isDark;
  final bool useProjectionDefault;
  final bool usePaidFill;

  final String Function(double) money;
  final String Function(double) money0;

  // Budgets by category
  final List<Segment> segments;
  final double total;

  // Performance
  final List<BudgetRow> budgetRows;
  final double totalSpentFill;
  final double totalBudget;
  final List<MapEntry<String, double>> unbudgeted;

  // Fixed / variable mix
  final double mixFixed;
  final double mixVariable;
  final List<FvMonth> mixHistory;

  // Trends (projection mode)
  final List<String> trendMonthLabels;
  final List<CategoryTrend> topTrends;

  const BudgetTab({
    super.key,
    required this.monthLabel,
    required this.appMode,
    required this.isDark,
    required this.useProjectionDefault,
    required this.usePaidFill,
    required this.money,
    required this.money0,
    required this.segments,
    required this.total,
    required this.budgetRows,
    required this.totalSpentFill,
    required this.totalBudget,
    required this.unbudgeted,
    required this.mixFixed,
    required this.mixVariable,
    required this.mixHistory,
    required this.trendMonthLabels,
    required this.topTrends,
  });

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  CategoryView _view = CategoryView.share;
  String? _hoveredId;
  String? _selectedId;
  final Set<String> _hiddenTrendIds = {};

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Budgets by Category ──────────────────────────────────────
        AnalyticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Budgets by Category',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  ViewToggle(
                    view: _view,
                    showRanked: false,
                    onChanged: (v) => setState(() => _view = v),
                  ),
                  const Spacer(),
                  Text(
                    widget.monthLabel,
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.total > 0
                    ? (widget.useProjectionDefault
                          ? 'Manually set limit, otherwise projection amount · ${widget.money(widget.total)}'
                          : 'Manually set amounts only · ${widget.money(widget.total)}')
                    : (widget.useProjectionDefault
                          ? 'No budgets yet — add projections or Set budgets'
                          : 'Set monthly budgets on categories to see targets'),
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              if (widget.segments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    widget.useProjectionDefault
                        ? 'No budgets yet — add projections or Set amounts on Categories'
                        : 'Set monthly amounts on Categories to see budgets',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                )
              else ...[
                if (_view == CategoryView.share)
                  ProportionalBar(
                    segments: widget.segments,
                    total: widget.total,
                    selectedId: _selectedId,
                    hoveredId: _hoveredId,
                    money0: widget.money0,
                    onHover: (id) => setState(() => _hoveredId = id),
                    onTap: (id) {
                      setState(() {
                        _selectedId = _selectedId == id ? null : id;
                      });
                    },
                  )
                else
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: CategoryTreemap(
                      items: [
                        for (final s in widget.segments)
                          TreemapItem(
                            id: s.id,
                            label: s.name,
                            value: s.amount,
                            valueLabel: widget.total > 0
                                ? '${widget.money0(s.amount)}  (${(s.amount / widget.total * 100).round()}%)'
                                : widget.money0(s.amount),
                            color: s.color,
                          ),
                      ],
                      selectedId: _selectedId,
                      hoveredId: _hoveredId,
                      onHover: (id) => setState(() => _hoveredId = id),
                      onTap: (id) {
                        setState(() {
                          _selectedId = _selectedId == id ? null : id;
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                SegmentLegend(
                  segments: widget.segments,
                  total: widget.total,
                  selectedId: _selectedId,
                  money0: widget.money0,
                  onTap: (id) {
                    setState(() {
                      _selectedId = _selectedId == id ? null : id;
                    });
                  },
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Budget Performance (above mix) ───────────────────────────
        AnalyticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Budget Performance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                widget.usePaidFill ? 'Paid vs Budget' : 'Spent vs Budget',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              if (widget.budgetRows.isEmpty && widget.totalSpentFill == 0)
                Text(
                  widget.useProjectionDefault
                      ? 'No budgets for this month. Add projections or Set budgets on Categories.'
                      : 'Set monthly budgets on Categories to see performance.',
                  style: TextStyle(color: colors.textSecondary),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${widget.money0(widget.totalSpentFill)} / ${widget.money0(widget.totalBudget)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:
                                  widget.totalBudget > 0 &&
                                      widget.totalSpentFill > widget.totalBudget
                                  ? AppColors.danger
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final over =
                              widget.totalBudget > 0 &&
                              widget.totalSpentFill > widget.totalBudget;
                          final factor = widget.totalBudget > 0
                              ? (widget.totalSpentFill / widget.totalBudget)
                                    .clamp(0.0, 1.0)
                              : 0.0;
                          return SizedBox(
                            height: 10,
                            width: width,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                children: [
                                  Container(
                                    color: widget.isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.08),
                                  ),
                                  ClipRect(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: factor,
                                      child: Container(
                                        width: width,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: over
                                                ? const [
                                                    Color(0xFFEF4444),
                                                    Color(0xFFEF4444),
                                                  ]
                                                : const [
                                                    Color(0xFF76ff71),
                                                    Color(0xFFEE850D),
                                                  ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                ...widget.budgetRows.map((r) {
                  final progress = (r.spent / r.budget).clamp(0.0, 1.5);
                  final over = r.spent > r.budget;
                  final cc = r.catColor;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${widget.money0(r.spent)} / ${widget.money0(r.budget)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: over ? const Color(0xFFEF4444) : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 8,
                            width: double.infinity,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ColoredBox(
                                  color: widget.isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.08),
                                ),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progress > 1 ? 1.0 : progress,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: over
                                          ? null
                                          : (cc.isGradient ? null : cc.start),
                                      gradient: over
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFEF4444),
                                                Color(0xFFF87171),
                                              ],
                                            )
                                          : (cc.isGradient
                                                ? LinearGradient(
                                                    colors: [cc.start, cc.end!],
                                                  )
                                                : null),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (widget.unbudgeted.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No budget',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            for (final e in widget.unbudgeted)
                              Text(
                                '${e.key}  ${widget.money0(e.value)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Projected expense mix ────────────────────────────────────
        _ProjectedExpenseMixCard(
          monthLabel: widget.monthLabel,
          mixFixed: widget.mixFixed,
          mixVariable: widget.mixVariable,
          mixHistory: widget.mixHistory,
          money: widget.money,
          money0: widget.money0,
          isDark: widget.isDark,
        ),

        // ── Category trends (projection only) ────────────────────────
        if (widget.appMode == AppMode.projection) ...[
          const SizedBox(height: 20),
          _CategoryTrendsCard(
            appMode: widget.appMode,
            trendMonthLabels: widget.trendMonthLabels,
            topTrends: widget.topTrends,
            hiddenTrendIds: _hiddenTrendIds,
            isDark: widget.isDark,
            onToggle: (id) {
              setState(() {
                if (_hiddenTrendIds.contains(id)) {
                  _hiddenTrendIds.remove(id);
                } else {
                  final visible =
                      widget.topTrends.length - _hiddenTrendIds.length;
                  if (visible <= 1) return;
                  _hiddenTrendIds.add(id);
                }
              });
            },
          ),
        ],
      ],
    );
  }
}

// ── Private cards (keep in this file) ────────────────────────────────

class _ProjectedExpenseMixCard extends StatelessWidget {
  final String monthLabel;
  final double mixFixed;
  final double mixVariable;
  final List<FvMonth> mixHistory;
  final String Function(double) money;
  final String Function(double) money0;
  final bool isDark;

  const _ProjectedExpenseMixCard({
    required this.monthLabel,
    required this.mixFixed,
    required this.mixVariable,
    required this.mixHistory,
    required this.money,
    required this.money0,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Projected expense mix',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                monthLabel,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Fixed vs variable · plan only (skipped excluded)',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 640;
              final left = FvThisMonthPanel(
                fixed: mixFixed,
                variable: mixVariable,
                money: money,
                money0: money0,
              );
              final right = SizedBox(
                height: 200,
                child: FvHistoryChart(
                  months: mixHistory,
                  isDark: isDark,
                  money0: money0,
                ),
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: left),
                    const SizedBox(width: 24),
                    Expanded(flex: 6, child: right),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 20), right],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              LegendDot(color: colors.primary, label: 'Fixed'),
              const SizedBox(width: 16),
              LegendDot(color: colors.warningColor, label: 'Variable'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryTrendsCard extends StatelessWidget {
  final AppMode appMode;
  final List<String> trendMonthLabels;
  final List<CategoryTrend> topTrends;
  final Set<String> hiddenTrendIds;
  final bool isDark;
  final ValueChanged<String> onToggle;

  const _CategoryTrendsCard({
    required this.appMode,
    required this.trendMonthLabels,
    required this.topTrends,
    required this.hiddenTrendIds,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Trends',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            appMode == AppMode.projection
                ? 'Top categories by budget (6 months)'
                : 'Actual spending by category (6 months)',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (topTrends.isEmpty)
            Text(
              'Not enough data yet',
              style: TextStyle(color: colors.textSecondary),
            )
          else ...[
            SizedBox(
              height: 220,
              child: CategoryTrendsChart(
                monthLabels: trendMonthLabels,
                trends: [
                  for (final t in topTrends)
                    if (!hiddenTrendIds.contains(t.id)) t,
                ],
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap a category to show or hide its line',
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final t in topTrends)
                  InkWell(
                    onTap: () => onToggle(t.id),
                    borderRadius: BorderRadius.circular(6),
                    child: Opacity(
                      opacity: hiddenTrendIds.contains(t.id) ? 0.35 : 1,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: t.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.name,
                            style: TextStyle(
                              fontSize: 12,
                              decoration: hiddenTrendIds.contains(t.id)
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
