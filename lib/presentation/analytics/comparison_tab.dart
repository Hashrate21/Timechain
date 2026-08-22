import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'analytics_shared.dart';

class ComparisonTab extends StatelessWidget {
  final bool isDark;
  final String Function(double) money0;

  final List<MonthCompare> monthly;
  final List<CombinedRow> combinedRows;

  const ComparisonTab({
    super.key,
    required this.isDark,
    required this.money0,
    required this.monthly,
    required this.combinedRows,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Projected vs Actual vs Targeted (this month) ─────────────
        AnalyticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Projected vs Actual vs Targeted',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                'Target = Set amount, else projection (if defaults on)',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Selected month by category',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      'Projected',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      'Actual',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      'Target',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (combinedRows.isEmpty)
                Text(
                  'No data for this month yet',
                  style: TextStyle(color: colors.textSecondary),
                )
              else
                ...combinedRows.map((r) {
                  final overBudget = r.budget > 0 && r.actual > r.budget;
                  final overPlan = r.projected > 0 && r.actual > r.projected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: r.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  r.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            r.projected > 0 ? money0(r.projected) : '—',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            money0(r.actual),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: overBudget || overPlan
                                  ? AppColors.danger
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            r.budget > 0 ? money0(r.budget) : '—',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // ── Projected vs Actual (6 months) ───────────────────────────
        AnalyticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Projected vs Actual',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Expense totals by month (last 6 months)',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 220,
                child: ProjectedActualChart(months: monthly, isDark: isDark),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  LegendDot(color: colors.primary, label: 'Projected'),
                  const SizedBox(width: 16),
                  const LegendDot(color: Color(0xFFF59E0B), label: 'Actual'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
