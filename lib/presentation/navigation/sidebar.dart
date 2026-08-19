import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/app_settings.dart';
import '../providers/settings_provider.dart';

class Sidebar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onHelpTap;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onHelpTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final appMode = ref.watch(appModeProvider);

    final items = <_NavItemData>[];

    // ===== DASHBOARD(S) =====
    if (appMode == AppMode.combined) {
      items.add(_NavItemData(Icons.dashboard_rounded, 'Dashboards', 0));
    } else {
      items.add(_NavItemData(Icons.dashboard_rounded, 'Dashboard', 0));
    }

    // ===== PROJECTION SIDE =====
    if (appMode == AppMode.projection || appMode == AppMode.combined) {
      items.addAll([
        _NavItemData(Icons.arrow_upward_rounded, 'Incomes', 1),
        _NavItemData(Icons.arrow_downward_rounded, 'Expenses', 2),
        _NavItemData(Icons.timeline_rounded, 'Projection', 3),
      ]);
    }

    // ===== ACTUALS SIDE =====
    if (appMode == AppMode.actuals || appMode == AppMode.combined) {
      final offset = appMode == AppMode.combined ? 4 : 1;

      items.addAll([
        _NavItemData(Icons.receipt_long_rounded, 'Transactions', offset + 0),
        _NavItemData(Icons.account_balance_rounded, 'Accounts', offset + 1),
      ]);
    }

    // ===== ALWAYS VISIBLE =====
    items.add(_NavItemData(Icons.insights_rounded, 'Analytics', 80));
    items.add(_NavItemData(Icons.category_rounded, 'Categories', 90));
    items.add(_NavItemData(Icons.settings_rounded, 'Settings', 99));

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Timechain',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // Mode indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                appMode.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Navigation items
          ...items.map((item) {
            return _NavItem(
              icon: item.icon,
              label: item.label,
              isSelected: selectedIndex == item.index,
              onTap: () => onItemSelected(item.index),
            );
          }),

          const Spacer(),

          // Help footer (not part of nav indices)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onHelpTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        size: 20,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Guide',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  final int index;

  _NavItemData(this.icon, this.label, this.index);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? colors.primary : colors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? colors.primary : colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
