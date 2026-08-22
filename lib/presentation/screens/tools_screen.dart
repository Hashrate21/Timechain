import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/debt_repayment_calculator.dart';
import '../widgets/savings_growth_calculator.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: colors.primary,
              unselectedLabelColor: colors.textSecondary,
              indicatorColor: colors.primary,
              dividerColor: colors.border,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Debt repayment'),
                Tab(text: 'Savings / growth'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              DebtRepaymentCalculator(),
              SavingsGrowthCalculator(),
            ],
          ),
        ),
      ],
    );
  }
}
