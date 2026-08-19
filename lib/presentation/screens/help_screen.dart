import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title is already in the shell title bar — optional to keep this
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: Text(
              'Thank you for choosing Timechain',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          TabBar(
            isScrollable: true,
            labelColor: colors.primary,
            unselectedLabelColor: colors.textSecondary,
            indicatorColor: colors.primary,
            tabs: const [
              Tab(text: 'User Guide'),
              Tab(text: 'Glossary'),
              Tab(text: 'About'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // ---------- User Guide ----------
                _ScrollBody(
                  children: [
                    _Heading('Modes'),
                    _Para([
                      'Combined shows projection and actuals together.',
                      'Projection Only is for planning.',
                      'Actuals Only tracks real spending and accounts.',
                    ]),

                    _Heading('Projection timeline'),
                    _Para([
                      'From/To chips set the range.',
                      'Paid and Skipped affect the timeline.',
                      'Paid on the timeline is not the same as an actual transaction.',
                    ]),

                    _Heading('Category budgets'),
                    _Para([
                      'A Set amount for the month overrides the projection total when '
                          '"Use projection as default budget" is on.',
                      'Categories use this calendar month, not the projection From/To range.',
                    ]),

                    _Heading('Income / Expense tabs'),
                    _Para([
                      'Income — enter income on the schedule you receive it.',
                      'Expense — enter expenses as you expect to pay them: monthly bills, '
                          'spending estimates, on your schedule.',
                    ]),

                    _Heading('Transactions'),
                    _Para([
                      'Enter real transactions as they appear in your accounts.',
                      'Allocate expenses to categories, track balances over time, '
                          'then use Analytics and the dashboard to see where money goes.',
                    ]),

                    _Heading('Accounts'),
                    _Para([
                      'Set a starting balance when you create an account.',
                      'Balances move with actual transactions over time — '
                          'bank accounts go up, loans go down.',
                    ]),

                    _Heading('Analytics'),
                    _Para([
                      'Yours to explore — trends, targets, and allocation visuals.',
                    ]),

                    _Heading('Categories'),
                    _Para([
                      'See spent or projected amounts against each category this month.',
                      'Set a budget on the category screen, or let projection fill the target '
                          'when that setting is on.',
                      'Depending on mode/settings, the bar reads as amount spent or amount '
                          'marked paid so far this month, versus the monthly target.',
                    ]),

                    _Heading('Settings'),
                    _Para([
                      'Create or switch budgets.',
                      'Change theme and color scheme.',
                      'Change app mode, defaults, and display options.',
                      'Import and export your data.',
                    ]),
                  ],
                ),

                // ---------- Glossary ----------
                _ScrollBody(
                  children: [
                    _Term('Set', [
                      'Manual budget amount you enter for a category for a given month.',
                    ]),
                    _Term('Projection', [
                      'Planned income/expense series expanded into occurrences by date.',
                    ]),
                    _Term('Target', [
                      'Universal term for budget — whether it is Set or taken from projection.',
                    ]),
                    _Term('Safe to spend', [
                      'Projected balance minus your safety buffer.',
                    ]),
                    _Term('Remaining', [
                      'Unpaid projected flow still ahead in the current range.',
                    ]),
                    _Term('Skip', [
                      'Ignore an occurrence in the plan without deleting the series.',
                    ]),
                  ],
                ),

                // ---------- About ----------
                _ScrollBody(
                  children: [
                    _Heading('Timechain'),
                    _Para(['Personal budget app for projections and actuals.']),
                    const SizedBox(height: 8),
                    _Term('Why?', [
                      'The projection engine is the core of the app.',
                      'It was hard to find a tool that clearly answers: ',
                      '   "How much do I have until payday?" ',
                      '   "Can I make it to the end of the month?" ',
                      '   "How much can I save?"',
                      'Timechain was built for those questions.',
                    ]),
                    _Term('Core', [
                      'Privacy first — no subscription, no accounts, no sign-ups, '
                          'no web version, no bank linking.',
                      'All data stays with you on your device.',
                    ]),
                    _Term('App structure', [
                      'Really two tools in one: a forward-looking projection engine, '
                          'and a past-looking spending analyzer.',
                      'Use Combined mode for the best of both.',
                    ]),
                    const SizedBox(height: 12),

                    Text(
                      'Timechainrecords@protonmail.com',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'Version 0.2.0',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollBody extends StatelessWidget {
  final List<Widget> children;
  const _ScrollBody({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

/// Any number of paragraphs — each string is a new line block.
///
/// ```dart
/// _Para(['One line.']),
/// _Para([
///   'First paragraph.',
///   'Second paragraph.',
///   'Third...',
/// ]),
/// ```
class _Para extends StatelessWidget {
  final List<String> lines;
  const _Para(this.lines);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = TextStyle(
      fontSize: 14,
      height: 1.45,
      color: colors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Text(lines[i], style: style),
          ],
        ],
      ),
    );
  }
}

/// Term + any number of definition lines.
///
/// ```dart
/// _Term('Skip', ['One line definition.']),
/// _Term('Core', [
///   'First sentence.',
///   'Second sentence.',
/// ]),
/// ```
class _Term extends StatelessWidget {
  final String term;
  final List<String> definitions;

  const _Term(this.term, this.definitions);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final defStyle = TextStyle(
      fontSize: 13,
      height: 1.4,
      color: colors.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            term,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < definitions.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Text(definitions[i], style: defStyle),
          ],
        ],
      ),
    );
  }
}
