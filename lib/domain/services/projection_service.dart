import '../entities/projected_transaction.dart';

class ProjectionOccurrence {
  final String id; // unique for this occurrence
  final String templateId; // original projected transaction id
  final String name;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final DateTime date;
  final bool isPaid;
  final RecurrenceType recurrence;

  const ProjectionOccurrence({
    required this.id,
    required this.templateId,
    required this.name,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.date,
    required this.isPaid,
    required this.recurrence,
  });
}

class ProjectionService {
  /// Expands all projected templates into individual occurrences
  /// between [start] and [end] (inclusive).
  List<ProjectionOccurrence> expand({
    required List<ProjectedTransaction> templates,
    required DateTime start,
    required DateTime end,
  }) {
    final List<ProjectionOccurrence> occurrences = [];

    for (final template in templates) {
      occurrences.addAll(
        _expandTemplate(template, start, end),
      );
    }

    // Sort by date, then by type (income before expense on same day)
    occurrences.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return a.type == TransactionType.income ? -1 : 1;
    });

    return occurrences;
  }

  List<ProjectionOccurrence> _expandTemplate(
    ProjectedTransaction template,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final List<ProjectionOccurrence> result = [];

    final DateTime? seriesEnd = template.recurrenceEnd == null
        ? null
        : DateTime(
            template.recurrenceEnd!.year,
            template.recurrenceEnd!.month,
            template.recurrenceEnd!.day,
          );

    DateTime current = DateTime(
      template.startDate.year,
      template.startDate.month,
      template.startDate.day,
    );

    if (current.isAfter(rangeEnd)) return result;

    // One-time
    if (template.recurrence == RecurrenceType.none) {
      if (!current.isBefore(rangeStart) &&
          !current.isAfter(rangeEnd) &&
          (seriesEnd == null || !current.isAfter(seriesEnd))) {
        result.add(_createOccurrence(template, current));
      }
      return result;
    }

    int safety = 0;
    const maxOccurrences = 500;

    while (!current.isAfter(rangeEnd) && safety < maxOccurrences) {
      // Stop generating past the template end date
      if (seriesEnd != null && current.isAfter(seriesEnd)) {
        break;
      }

      if (!current.isBefore(rangeStart)) {
        result.add(_createOccurrence(template, current));
      }

      current = _nextDate(current, template);
      safety++;
    }

    return result;
  }
  
  DateTime _nextDate(DateTime current, ProjectedTransaction template) {
    switch (template.recurrence) {
      case RecurrenceType.weekly:
        return current.add(const Duration(days: 7));

      case RecurrenceType.biweekly:
        return current.add(const Duration(days: 14));

      case RecurrenceType.monthly:
        return DateTime(current.year, current.month + 1, template.recurrenceDay ?? current.day);

      case RecurrenceType.twiceMonthly:
        final day1 = template.recurrenceDay ?? current.day;
        final day2 = template.recurrenceDay2 ?? 15;

        if (current.day == day1) {
          // Go to day2 of same month (or next month if day2 < day1)
          if (day2 > day1) {
            return DateTime(current.year, current.month, day2);
          } else {
            return DateTime(current.year, current.month + 1, day2);
          }
        } else {
          // Go to day1 of next month
          return DateTime(current.year, current.month + 1, day1);
        }

      case RecurrenceType.quarterly:
        return DateTime(current.year, current.month + 3, template.recurrenceDay ?? current.day);

      case RecurrenceType.yearly:
        return DateTime(current.year + 1, current.month, template.recurrenceDay ?? current.day);

      case RecurrenceType.none:
        return current.add(const Duration(days: 36500)); // far future
    }
  }

  ProjectionOccurrence _createOccurrence(
    ProjectedTransaction template,
    DateTime date,
  ) {
    return ProjectionOccurrence(
      id: '${template.id}_${date.toIso8601String().substring(0, 10)}',
      templateId: template.id,
      name: template.name,
      amount: template.amount,
      type: template.type,
      categoryId: template.categoryId,
      date: date,
      isPaid: template.isPaid, // temporary - will become per-occurrence later
      recurrence: template.recurrence,
    );
  }

  /// Calculates running balance
  List<double> calculateRunningBalance({
    required List<ProjectionOccurrence> occurrences,
    required double startingBalance,
  }) {
    double balance = startingBalance;
    final List<double> balances = [];

    for (final occ in occurrences) {
      if (occ.type == TransactionType.income) {
        balance += occ.amount;
      } else {
        balance -= occ.amount;
      }
      balances.add(balance);
    }

    return balances;
  }
}