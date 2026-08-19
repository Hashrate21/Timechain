import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/budget_target.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/snackbars.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/projected_transaction.dart';
import '../providers/app_providers.dart';
import '../widgets/add_category_dialog.dart';
import '../../core/utils/category_color.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final transactionsAsync = ref.watch(actualTransactionsProvider);
    final templatesAsync = ref.watch(projectedTransactionsProvider);
    final service = ref.watch(projectionServiceProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final paidIdsAsync = ref.watch(paidOccurrenceIdsProvider);
    final skippedIds =
        ref.watch(skippedOccurrenceIdsProvider).valueOrNull ?? <String>{};
    final budgetsAsync = ref.watch(currentMonthCategoryBudgetsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
          child: Row(
            children: [
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddCategoryDialog(),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: categoriesAsync.when(
            data: (categories) {
              return budgetsAsync.when(
                data: (budgets) {
                  return transactionsAsync.when(
                    data: (transactions) {
                      return templatesAsync.when(
                        data: (templates) {
                          final now = DateTime.now();
                          final monthStart = DateTime(now.year, now.month, 1);
                          final monthEnd = DateTime(now.year, now.month + 1, 0);

                          final occurrences = service.expand(
                            templates: templates,
                            start: monthStart,
                            end: monthEnd,
                          );
                          final settings =
                              settingsAsync.valueOrNull ?? const AppSettings();
                          final appMode = settings.appMode;

                          final useProjectionDefault =
                              appMode != AppMode.actuals &&
                              settings.useProjectionAsDefaultTarget;

                          final usePaidFill = appMode == AppMode.projection;

                          final spentByCategory = <String, double>{};
                          for (final t in transactions) {
                            if (t.type == TransactionType.expense &&
                                t.date.year == now.year &&
                                t.date.month == now.month) {
                              spentByCategory[t.categoryId] =
                                  (spentByCategory[t.categoryId] ?? 0) +
                                  t.amount;
                            }
                          }

                          final projectedByCategory = <String, double>{};
                          for (final o in occurrences) {
                            if (o.type != TransactionType.expense) continue;
                            if (skippedIds.contains(o.id)) continue;
                            projectedByCategory[o.categoryId] =
                                (projectedByCategory[o.categoryId] ?? 0) +
                                o.amount;
                          }

                          final paidIds =
                              paidIdsAsync.valueOrNull ?? <String>{};
                          final paidProjectedByCategory = <String, double>{};
                          for (final o in occurrences) {
                            if (o.type != TransactionType.expense) continue;
                            if (skippedIds.contains(o.id)) continue;
                            if (!paidIds.contains(o.id)) continue;
                            paidProjectedByCategory[o.categoryId] =
                                (paidProjectedByCategory[o.categoryId] ?? 0) +
                                o.amount;
                          }

                          if (categories.isEmpty) {
                            return Center(
                              child: Text(
                                'No categories yet',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            );
                          }

                          final incomeCats = categories
                              .where((c) => c.isIncome && !c.isTransfer)
                              .toList();
                          final expenseCats = categories
                              .where((c) => !c.isIncome && !c.isTransfer)
                              .toList();
                          final transferCats = categories
                              .where((c) => c.isTransfer)
                              .toList();

                          double fillOf(Category c) => usePaidFill
                              ? (paidProjectedByCategory[c.id] ?? 0.0)
                              : (spentByCategory[c.id] ?? 0.0);

                          EffectiveTarget effOf(Category c) => effectiveTarget(
                            categoryId: c.id,
                            useProjectionAsDefault: useProjectionDefault,
                            manualBudgets: budgets,
                            projectedByCategory: projectedByCategory,
                          );

                          expenseCats.sort((a, b) {
                            final fa = fillOf(a);
                            final fb = fillOf(b);
                            final ea = effOf(a);
                            final eb = effOf(b);

                            final aEmpty = fa <= 0 && !ea.hasTarget;
                            final bEmpty = fb <= 0 && !eb.hasTarget;
                            if (aEmpty != bEmpty) return aEmpty ? 1 : -1;

                            if (ea.hasTarget && eb.hasTarget) {
                              return (fb / eb.amount).compareTo(fa / ea.amount);
                            }

                            if (ea.hasTarget != eb.hasTarget) {
                              return ea.hasTarget ? -1 : 1;
                            }

                            return fb.compareTo(fa);
                          });

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                            children: [
                              if (expenseCats.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const _SectionHeader(
                                      title: 'Expense Categories',
                                    ),
                                    const Spacer(),
                                    Text(
                                      appMode == AppMode.projection
                                          ? 'Expenses are items marked Paid this month'
                                          : 'Expenses are actual spending this month',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...expenseCats.map(
                                  (c) => _CategoryCard(
                                    category: c,
                                    fillAmount: usePaidFill
                                        ? (paidProjectedByCategory[c.id] ?? 0)
                                        : (spentByCategory[c.id] ?? 0),
                                    projected: projectedByCategory[c.id] ?? 0,
                                    manualBudget: budgets[c.id] ?? 0,
                                    useProjectionDefault: useProjectionDefault,
                                    fillIsActual: !usePaidFill,
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                              if (incomeCats.isNotEmpty) ...[
                                const _SectionHeader(
                                  title: 'Income Categories',
                                ),
                                const SizedBox(height: 10),
                                ...incomeCats.map(
                                  (c) => _CategoryCard(
                                    category: c,
                                    fillAmount: 0,
                                    projected: 0,
                                    manualBudget: 0,
                                    useProjectionDefault: false,
                                    fillIsActual: true,
                                    showProgress: false,
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                              if (transferCats.isNotEmpty) ...[
                                const _SectionHeader(title: 'Transfer'),
                                const SizedBox(height: 10),
                                ...transferCats.map(
                                  (c) => _CategoryCard(
                                    category: c,
                                    fillAmount: 0,
                                    projected: 0,
                                    manualBudget: 0,
                                    useProjectionDefault: false,
                                    fillIsActual: true,
                                    showProgress: false,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Center(child: Text('Error: $e')),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  final Category category;
  final double fillAmount;
  final double projected;
  final double manualBudget;
  final bool useProjectionDefault;
  final bool fillIsActual;
  final bool showProgress;

  const _CategoryCard({
    required this.category,
    required this.fillAmount,
    required this.projected,
    required this.manualBudget,
    required this.useProjectionDefault,
    this.fillIsActual = true,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const AppSettings();

    String money(double v) => formatMoney(
      v,
      symbol: settings.currencySymbol,
      showSymbol: settings.showCurrencySymbol,
      negativeFormat: settings.negativeFormat,
      decimals: 0,
    );

    final catColor = CategoryColor.parse(
      category.color,
      fallback: colors.primary,
    );

    final eff = effectiveTarget(
      categoryId: category.id,
      useProjectionAsDefault: useProjectionDefault,
      manualBudgets: {category.id: manualBudget},
      projectedByCategory: {category.id: projected},
    );

    final hasPlan = showProgress && eff.hasTarget;
    final progress = hasPlan ? (fillAmount / eff.amount).clamp(0.0, 1.5) : 0.0;
    final overPlan = hasPlan && fillAmount > eff.amount;

    final sourceShort = switch (eff.source) {
      TargetSource.manual => 'Set',
      TargetSource.projection => 'Proj.',
      TargetSource.none => '',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: catColor.decoration(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (showProgress)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: hasPlan
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              sourceShort,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: money(fillAmount),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: overPlan
                                          ? colors.dangerColor
                                          : colors.textPrimary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / ${money(eff.amount)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: overPlan
                                          ? colors.dangerColor
                                          : colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : (fillAmount > 0
                            ? Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: money(fillAmount),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' / —',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink()),
                ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: colors.textSecondary,
                ),
                onSelected: (value) async {
                  final repo = ref.read(categoryRepositoryProvider);

                  if (value == 'edit') {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          AddCategoryDialog(existing: category),
                    );
                  }

                  if (value == 'delete') {
                    final name = category.name;
                    final toRestore = category;

                    await repo.delete(category.id);
                    ref.invalidate(categoriesProvider);
                    ref.invalidate(currentMonthCategoryBudgetsProvider);

                    if (!context.mounted) return;
                    showUndoSnackBar(
                      context,
                      message: '"$name" deleted',
                      onUndo: () async {
                        await repo.insert(toRestore);
                        ref.invalidate(categoriesProvider);
                      },
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          if (showProgress && hasPlan) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress > 1 ? 1.0 : progress,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: overPlan
                              ? null
                              : (catColor.isGradient ? null : catColor.start),
                          gradient: overPlan
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFEF4444),
                                    Color(0xFFF87171),
                                  ],
                                )
                              : (catColor.isGradient
                                    ? LinearGradient(
                                        colors: [catColor.start, catColor.end!],
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
        ],
      ),
    );
  }
}
