import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'domain/entities/app_settings.dart';
import 'domain/entities/projected_transaction.dart';
import 'presentation/navigation/sidebar.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/accounts_screen.dart';
import 'presentation/screens/actual_transactions_screen.dart';
import 'presentation/screens/actuals_dashboard_screen.dart';
import 'presentation/screens/analytics_screen.dart';
import 'presentation/screens/categories_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/help_screen.dart';
import 'presentation/screens/projected_list_screen.dart';
import 'presentation/screens/projection_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/tools_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const size = Size(1200, 920);
    const options = WindowOptions(
      size: size,
      minimumSize: Size(1100, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'Budget App',
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: BudgetApp()));
}

class BudgetApp extends ConsumerWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      data: (settings) {
        final themeMode = switch (settings.themeMode) {
          ThemeModeSetting.light => ThemeMode.light,
          ThemeModeSetting.dark => ThemeMode.dark,
          ThemeModeSetting.system => ThemeMode.system,
        };

        return MaterialApp(
          title: 'Budget App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(settings.colorScheme),
          darkTheme: AppTheme.dark(settings.colorScheme),
          themeMode: themeMode,
          home: const HomeShell(),
        );
      },
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (err, stack) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Error: $err'))),
      ),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selectedIndex = 0;
  bool _showProjectionDashboard = true;
  bool _showHelp = false;

  @override
  Widget build(BuildContext context) {
    final appMode = ref.watch(appModeProvider);

    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _showHelp ? -1 : _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _showHelp = false;
                _selectedIndex = index;
              });
            },
            onHelpTap: () {
              setState(() => _showHelp = true);
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 8),
                  child: Row(
                    children: [
                      Text(
                        _showHelp
                            ? 'Guide'
                            : _getTitle(appMode, _selectedIndex),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (!_showHelp &&
                          appMode == AppMode.combined &&
                          _selectedIndex == 0) ...[
                        const SizedBox(width: 24),
                        _DashboardToggle(
                          showProjection: _showProjectionDashboard,
                          onChanged: (value) {
                            setState(() {
                              _showProjectionDashboard = value;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _showHelp
                      ? const HelpScreen()
                      : _buildContent(appMode, _selectedIndex),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle(AppMode mode, int index) {
    if (index == 0) {
      if (mode == AppMode.combined) return 'Dashboards';
      return 'Dashboard';
    }

    if (mode == AppMode.projection || mode == AppMode.combined) {
      switch (index) {
        case 1:
          return 'Incomes';
        case 2:
          return 'Expenses';
        case 3:
          return 'Projection';
      }
    }

    if (mode == AppMode.actuals) {
      switch (index) {
        case 1:
          return 'Transactions';
        case 2:
          return 'Accounts';
      }
    }

    if (mode == AppMode.combined) {
      switch (index) {
        case 4:
          return 'Transactions';
        case 5:
          return 'Accounts';
      }
    }
    if (index == 80) return 'Analytics';
    if (index == 90) return 'Categories';
    if (index == 70) return 'Tools';
    if (index == 99) return 'Settings';

    return 'Budget';
  }

  Widget _buildContent(AppMode mode, int index) {
    if (index == 0) {
      if (mode == AppMode.combined) {
        return _showProjectionDashboard
            ? const DashboardScreen()
            : const ActualsDashboardScreen();
      }
      if (mode == AppMode.projection) return const DashboardScreen();
      if (mode == AppMode.actuals) {
        return const ActualsDashboardScreen();
      }
    }

    if (mode == AppMode.projection || mode == AppMode.combined) {
      switch (index) {
        case 1:
          return const ProjectedListScreen(type: TransactionType.income);
        case 2:
          return const ProjectedListScreen(type: TransactionType.expense);
        case 3:
          return const ProjectionScreen();
      }
    }

    if (mode == AppMode.actuals) {
      switch (index) {
        case 1:
          return const ActualTransactionsScreen();
        case 2:
          return const AccountsScreen();
      }
    }

    if (mode == AppMode.combined) {
      switch (index) {
        case 4:
          return const ActualTransactionsScreen();
        case 5:
          return const AccountsScreen();
      }
    }

    if (index == 80) return const AnalyticsScreen();
    if (index == 90) return const CategoriesScreen();
    if (index == 70) return const ToolsScreen();
    if (index == 99) return const SettingsScreen();

    return const Center(child: Text('Coming soon'));
  }
}

class _DashboardToggle extends StatelessWidget {
  final bool showProjection;
  final ValueChanged<bool> onChanged;

  const _DashboardToggle({
    required this.showProjection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            label: 'Projection',
            selected: showProjection,
            onTap: () => onChanged(true),
          ),
          _ToggleButton(
            label: 'Actuals',
            selected: !showProjection,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
