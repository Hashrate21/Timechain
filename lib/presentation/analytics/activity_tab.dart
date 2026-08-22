import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/app_settings.dart';
import '../widgets/category_treemap.dart';
import 'analytics_shared.dart';

class ActivityTab extends StatefulWidget {
  final String monthLabel;
  final AppMode appMode;
  final bool isDark;

  final String Function(double) money;
  final String Function(double) money0;

  // Actual spending by category
  final List<Segment> spendSegments;
  final double spendTotal;
  final Map<String, double> spent;

  // Spending detail
  final List<DetailCatOption> detailCategoryOptions;
  final List<DescSlice> Function(String? catId) slicesFor;

  // Net transfers
  final List<NetTransferRow> netRows;

  // Trends (non-projection)
  final List<String> trendMonthLabels;
  final List<CategoryTrend> topTrends;

  const ActivityTab({
    super.key,
    required this.monthLabel,
    required this.appMode,
    required this.isDark,
    required this.money,
    required this.money0,
    required this.spendSegments,
    required this.spendTotal,
    required this.spent,
    required this.detailCategoryOptions,
    required this.slicesFor,
    required this.netRows,
    required this.trendMonthLabels,
    required this.topTrends,
  });

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  CategoryView _spendView = CategoryView.share;
  String? _spendHoveredId;
  String? _spendSelectedId;

  String? _detailLeftCatId;
  String? _detailRightCatId;
  String? _detailLeftHovered;
  String? _detailLeftSelected;
  String? _detailRightHovered;
  String? _detailRightSelected;
  bool _detailDefaultsApplied = false;

  final Set<String> _hiddenTrendIds = {};

  @override
  void didUpdateWidget(covariant ActivityTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset detail picks when month / data set changes
    if (oldWidget.monthLabel != widget.monthLabel ||
        oldWidget.detailCategoryOptions != widget.detailCategoryOptions) {
      _detailDefaultsApplied = false;
      _detailLeftCatId = null;
      _detailRightCatId = null;
    }
  }

  void _applyDetailDefaultsIfNeeded() {
    final opts = widget.detailCategoryOptions;
    if (_detailDefaultsApplied) {
      if (opts.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _detailLeftCatId = null;
            _detailRightCatId = null;
            _detailDefaultsApplied = false;
          });
        });
      }
      return;
    }
    if (opts.isEmpty) return;

    final multi = opts.where((c) => c.distinctCount >= 2).toList();
    final pool = multi.isNotEmpty ? multi : opts;

    final bySpend = List<DetailCatOption>.from(pool)
      ..sort((a, b) => b.total.compareTo(a.total));
    final byTx = List<DetailCatOption>.from(pool)
      ..sort((a, b) => b.txCount.compareTo(a.txCount));

    final leftId = bySpend.first.id;
    var rightId = byTx.first.id;
    if (rightId == leftId && byTx.length > 1) {
      rightId = byTx[1].id;
    } else if (rightId == leftId && bySpend.length > 1) {
      rightId = bySpend[1].id;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _detailDefaultsApplied) return;
      setState(() {
        _detailLeftCatId = leftId;
        _detailRightCatId = rightId;
        _detailDefaultsApplied = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    _applyDetailDefaultsIfNeeded();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Actual Spending by Category ──────────────────────────────
        AnalyticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Actual Spending by Category',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  ViewToggle(
                    view: _spendView,
                    showRanked: true,
                    onChanged: (v) => setState(() => _spendView = v),
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
                widget.spendTotal > 0
                    ? 'Total · ${widget.money(widget.spendTotal)}'
                    : 'No expenses recorded this month',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              if (widget.spendSegments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No expenses this month',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                )
              else ...[
                if (_spendView == CategoryView.share)
                  ProportionalBar(
                    segments: widget.spendSegments,
                    total: widget.spendTotal,
                    selectedId: _spendSelectedId,
                    hoveredId: _spendHoveredId,
                    money0: widget.money0,
                    onHover: (id) => setState(() => _spendHoveredId = id),
                    onTap: (id) {
                      setState(() {
                        _spendSelectedId = _spendSelectedId == id ? null : id;
                      });
                    },
                  )
                else if (_spendView == CategoryView.treemap)
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: CategoryTreemap(
                      items: [
                        for (final s in widget.spendSegments)
                          TreemapItem(
                            id: s.id,
                            label: s.name,
                            value: s.amount,
                            valueLabel: widget.spendTotal > 0
                                ? '${widget.money0(s.amount)}  (${(s.amount / widget.spendTotal * 100).round()}%)'
                                : widget.money0(s.amount),
                            color: s.color,
                          ),
                      ],
                      selectedId: _spendSelectedId,
                      hoveredId: _spendHoveredId,
                      onHover: (id) => setState(() => _spendHoveredId = id),
                      onTap: (id) {
                        setState(() {
                          _spendSelectedId = _spendSelectedId == id ? null : id;
                        });
                      },
                    ),
                  )
                else
                  SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: RankedSpendBars(
                      segments: widget.spendSegments,
                      total: widget.spendTotal,
                      selectedId: _spendSelectedId,
                      hoveredId: _spendHoveredId,
                      money0: widget.money0,
                      isDark: widget.isDark,
                      onHover: (id) => setState(() => _spendHoveredId = id),
                      onTap: (id) {
                        setState(() {
                          _spendSelectedId = _spendSelectedId == id ? null : id;
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                SegmentLegend(
                  segments: widget.spendSegments,
                  total: widget.spendTotal,
                  selectedId: _spendSelectedId,
                  money0: widget.money0,
                  onTap: (id) {
                    setState(() {
                      _spendSelectedId = _spendSelectedId == id ? null : id;
                    });
                  },
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Spending detail ──────────────────────────────────────────
        _SpendingDetailCard(
          monthLabel: widget.monthLabel,
          detailCategoryOptions: widget.detailCategoryOptions,
          spent: widget.spent,
          slicesFor: widget.slicesFor,
          money: widget.money,
          money0: widget.money0,
          leftCatId: _detailLeftCatId,
          rightCatId: _detailRightCatId,
          leftHovered: _detailLeftHovered,
          leftSelected: _detailLeftSelected,
          rightHovered: _detailRightHovered,
          rightSelected: _detailRightSelected,
          onLeftCatChanged: (id) => setState(() {
            _detailLeftCatId = id;
            _detailLeftSelected = null;
            _detailLeftHovered = null;
          }),
          onRightCatChanged: (id) => setState(() {
            _detailRightCatId = id;
            _detailRightSelected = null;
            _detailRightHovered = null;
          }),
          onLeftHover: (id) => setState(() => _detailLeftHovered = id),
          onRightHover: (id) => setState(() => _detailRightHovered = id),
          onLeftTap: (id) => setState(() {
            _detailLeftSelected = _detailLeftSelected == id ? null : id;
          }),
          onRightTap: (id) => setState(() {
            _detailRightSelected = _detailRightSelected == id ? null : id;
          }),
        ),

        const SizedBox(height: 20),

        // ── Net transfers ────────────────────────────────────────────
        _NetTransfersCard(
          monthLabel: widget.monthLabel,
          netRows: widget.netRows,
          money: widget.money,
          money0: widget.money0,
        ),

        // ── Category trends (non-projection) ─────────────────────────
        if (widget.appMode != AppMode.projection) ...[
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

// ── Private cards ────────────────────────────────────────────────────

class _SpendingDetailCard extends StatelessWidget {
  final String monthLabel;
  final List<DetailCatOption> detailCategoryOptions;
  final Map<String, double> spent;
  final List<DescSlice> Function(String? catId) slicesFor;
  final String Function(double) money;
  final String Function(double) money0;
  final String? leftCatId;
  final String? rightCatId;
  final String? leftHovered;
  final String? leftSelected;
  final String? rightHovered;
  final String? rightSelected;
  final ValueChanged<String> onLeftCatChanged;
  final ValueChanged<String> onRightCatChanged;
  final ValueChanged<String?> onLeftHover;
  final ValueChanged<String?> onRightHover;
  final ValueChanged<String> onLeftTap;
  final ValueChanged<String> onRightTap;

  const _SpendingDetailCard({
    required this.monthLabel,
    required this.detailCategoryOptions,
    required this.spent,
    required this.slicesFor,
    required this.money,
    required this.money0,
    required this.leftCatId,
    required this.rightCatId,
    required this.leftHovered,
    required this.leftSelected,
    required this.rightHovered,
    required this.rightSelected,
    required this.onLeftCatChanged,
    required this.onRightCatChanged,
    required this.onLeftHover,
    required this.onRightHover,
    required this.onLeftTap,
    required this.onRightTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final leftSlices = slicesFor(leftCatId);
    final rightSlices = slicesFor(rightCatId);
    final leftTotal = leftCatId != null ? (spent[leftCatId!] ?? 0) : 0.0;
    final rightTotal = rightCatId != null ? (spent[rightCatId!] ?? 0) : 0.0;

    Widget side({
      required String? catId,
      required double catTotal,
      required List<DescSlice> slices,
      required String? hovered,
      required String? selected,
      required ValueChanged<String> onCatChanged,
      required ValueChanged<String?> onHover,
      required ValueChanged<String> onTap,
    }) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: detailCategoryOptions.isEmpty
                      ? Text(
                          'No categories',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            isDense: true,
                            value:
                                catId != null &&
                                    detailCategoryOptions.any(
                                      (c) => c.id == catId,
                                    )
                                ? catId
                                : detailCategoryOptions.first.id,
                            items: [
                              for (final c in detailCategoryOptions)
                                DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) onCatChanged(v);
                            },
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  money(catTotal),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (slices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No spending in this category',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              )
            else
              DescRankedBars(
                slices: slices,
                total: catTotal,
                selectedId: selected,
                hoveredId: hovered,
                money0: money0,
                onHover: onHover,
                onTap: onTap,
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Spending detail',
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
            'Category breakdown',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (detailCategoryOptions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No expenses this month',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                side(
                  catId: leftCatId,
                  catTotal: leftTotal,
                  slices: leftSlices,
                  hovered: leftHovered,
                  selected: leftSelected,
                  onCatChanged: onLeftCatChanged,
                  onHover: onLeftHover,
                  onTap: onLeftTap,
                ),
                const SizedBox(width: 24),
                side(
                  catId: rightCatId,
                  catTotal: rightTotal,
                  slices: rightSlices,
                  hovered: rightHovered,
                  selected: rightSelected,
                  onCatChanged: onRightCatChanged,
                  onHover: onRightHover,
                  onTap: onRightTap,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _NetTransfersCard extends StatelessWidget {
  final String monthLabel;
  final List<NetTransferRow> netRows;
  final String Function(double) money;
  final String Function(double) money0;

  const _NetTransfersCard({
    required this.monthLabel,
    required this.netRows,
    required this.money,
    required this.money0,
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
                'Net transfers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                monthLabel,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Money moved between accounts (not income or spending)',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (netRows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No transfers this month',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            )
          else
            NetTransfersChart(rows: netRows, money: money, money0: money0),
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
