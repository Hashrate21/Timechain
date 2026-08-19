enum TargetSource { none, manual, projection }

class EffectiveTarget {
  final double amount;
  final TargetSource source;
  const EffectiveTarget(this.amount, this.source);
  bool get hasTarget => amount > 0;
}

EffectiveTarget effectiveTarget({
  required String categoryId,
  required bool useProjectionAsDefault,
  required Map<String, double> manualBudgets, // categoryId -> amount for month
  required Map<String, double> projectedByCategory, // same month
}) {
  final manual = manualBudgets[categoryId];
  if (manual != null && manual > 0) {
    return EffectiveTarget(manual, TargetSource.manual);
  }
  if (useProjectionAsDefault) {
    final p = projectedByCategory[categoryId] ?? 0;
    if (p > 0) return EffectiveTarget(p, TargetSource.projection);
  }
  return const EffectiveTarget(0, TargetSource.none);
}