import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchAny(Iterable<String> parts) {
    if (_query.isEmpty) return true;
    for (final p in parts) {
      if (p.toLowerCase().contains(_query)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final guideSections = <_GuideSection>[
      _GuideSection('Modes', [
        'Combined shows projection and actuals together.',
        'Projection Only is for planning.',
        'Actuals Only tracks real spending and accounts.',
      ]),
      _GuideSection('Projection timeline', [
        'From/To chips set the range.',
        'Paid and Skipped affect the timeline.',
        'Paid on the timeline is not the same as an actual transaction.',
      ]),
      _GuideSection('Category budgets', [
        'A Set amount for the month overrides the projection total when '
            '"Use projection as default budget" is on.',
        'Categories use this calendar month, not the projection From/To range.',
      ]),
      _GuideSection('Income / Expense tabs', [
        'Income — enter income on the schedule you receive it.',
        'Expense — enter expenses as you expect to pay them: monthly bills, '
            'spending estimates, on your schedule.',
      ]),
      _GuideSection('Transactions', [
        'Enter real transactions as they appear in your accounts.',
        'Allocate expenses to categories, track balances over time, '
            'then use Analytics and the dashboard to see where money goes.',
      ]),
      _GuideSection('Transfers', [
        'A transfer moves money between accounts. It is not income and not an expense.',
        'Use Transfer when both sides are accounts you track (e.g. Checking > Savings).',
      ]),
      _GuideSection('Untracked', [
        'Untracked is a special counterparty for money that leaves or enters an account '
            'without the account being tracked in this program — brokerage, kids’ accounts, '
            'external savings, and similar items.',
        'Transfer Checking → Untracked lowers Checking only. Transfer Untracked → Checking '
            'raises Checking only. Neither counts as an expense or income.',
        'Untracked does not appear on the Accounts screen or in net worth. '
            'Manage externals in Settings (add, rename, archive, restore).',
        'To track a real balance inside the app, add a normal account instead and transfer '
            'between tracked accounts.',
      ]),
      _GuideSection('Accounts', [
        'Set a starting balance when you create an account.',
        'Balances move with actual transactions over time — '
            'bank accounts go up, loans go down.',
      ]),
      _GuideSection('Import / Export CSV', [
        'On the import screen, data must be shown using comma separated values.',
        'date, account, description, category, type, amount, notes',
        'Standard example --> 2026-07-17,Credit Card,Amazon,Entertainment,Expense,500,party supplies',
        'Transfer example --> 2026-07-17,Checking > Credit Card,Paid CC,,transfer,500,june statement',
        'Untracked account example --> 2026-07-17,Checking > Untracked,Move to savings,,transfer,500,',
        'Notes may be left blank, category may be left blank for transfers; if transfer, show movement with ">" format is "from > to" ',
        '------',
        'Format',
        'Date = YYYY-MM-DD',
        'Account = An existing account from accounts screen or your Untracked account name',
        'Description = Write whatever you want',
        'Category = A category from your list of categories',
        'Type = Income / Expense / Transfer',
        'Amount = any number up to 2 decimal places. Do not include commas.',
        '     eg. 5000, 5000.0, and 5000.00 are okay; 5,000 is incorrect',
        'Notes = any additional info you want to include',
      ]),
      _GuideSection('Analytics', [
        'Yours to explore — trends, budgets, spending, and allocation visuals.',
      ]),
      _GuideSection('Categories', [
        'See spent or projected amounts against each category this month.',
        'Set a budget on the category screen, or let projection fill the target '
            'when that setting is on.',
        'Depending on mode/settings, the bar reads as amount spent or amount '
            'marked paid so far this month, versus the monthly target.',
      ]),
      _GuideSection('Settings', [
        'Create or switch budgets.',
        'Change theme and color scheme.',
        'Change app mode, defaults, and display options.',
        'Import and export your data.',
        'Manage external (untracked) accounts: add, edit, archive, restore.',
      ]),
    ];

    final glossary = <_GlossaryEntry>[
      _GlossaryEntry('Set', [
        'Manual budget amount you enter for a category for a given month.',
      ]),
      _GlossaryEntry('Projection', [
        'Planned income/expense series expanded into occurrences by date.',
      ]),
      _GlossaryEntry('Target', [
        'Universal term for budget — whether it is Set or taken from projection.',
      ]),
      _GlossaryEntry('Safe to spend', [
        'Projected balance minus your safety buffer.',
      ]),
      _GlossaryEntry('Remaining', [
        'Unpaid projected flow still ahead in the current range.',
      ]),
      _GlossaryEntry('Skip', [
        'Ignore an occurrence in the plan without deleting the series.',
      ]),
      _GlossaryEntry('External / Untracked', [
        'An account that is outside of this budget file.',
      ]),
      _GlossaryEntry('Transfer', [
        'Actual movement between accounts (or Untracked). Excluded from income and expense totals.',
      ]),
    ];

    final filteredGuide = guideSections
        .where((s) => _matchAny([s.title, ...s.lines]))
        .toList();
    final filteredGlossary = glossary
        .where((e) => _matchAny([e.term, ...e.definitions]))
        .toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search guide & glossary…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.border),
                ),
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
                    if (filteredGuide.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          'No guide topics match “${_searchController.text.trim()}”',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    else
                      for (final s in filteredGuide) ...[
                        _Heading(s.title),
                        _Para(s.lines),
                      ],
                  ],
                ),

                // ---------- Glossary ----------
                _ScrollBody(
                  children: [
                    if (filteredGlossary.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          'No glossary terms match “${_searchController.text.trim()}”',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    else
                      for (final e in filteredGlossary)
                        _Term(e.term, e.definitions),
                  ],
                ),

                // ---------- About ----------
                _ScrollBody(
                  children: [
                    if (_query.isNotEmpty &&
                        !_matchAny([
                          'Timechain',
                          'Personal budget app for projections and actuals.',
                          'Why?',
                          'projection engine',
                          'How much do I have until payday',
                          'Core',
                          'Privacy',
                          'App structure',
                          'Timechainrecords@protonmail.com',
                          'Version 0.2.2',
                        ]))
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          'No About content matches “${_searchController.text.trim()}”',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    else ...[
                      _Heading('Timechain'),
                      _Para([
                        'Personal budget app for projections and actuals.',
                      ]),
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
                        'Version 0.2.1',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
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

class _GuideSection {
  final String title;
  final List<String> lines;
  const _GuideSection(this.title, this.lines);
}

class _GlossaryEntry {
  final String term;
  final List<String> definitions;
  const _GlossaryEntry(this.term, this.definitions);
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
