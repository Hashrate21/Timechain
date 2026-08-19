import '../database/database_helper.dart';
import '../../domain/entities/app_settings.dart';

class SettingsRepository {
  final DatabaseHelper dbHelper;

  SettingsRepository(this.dbHelper);

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is! String || value.isEmpty) return null;
    try {
      final d = DateTime.parse(value);
      return DateTime(d.year, d.month, d.day);
    } catch (_) {
      return null;
    }
  }

  String? _dateToDb(DateTime? d) {
    if (d == null) return null;
    final x = DateTime(d.year, d.month, d.day);
    return x.toIso8601String().substring(0, 10);
  }

  Future<AppSettings> getSettings() async {
    final db = await dbHelper.database;
    final maps = await db.query('settings', where: 'id = ?', whereArgs: [1]);

    if (maps.isEmpty) {
      return const AppSettings();
    }

    final map = maps.first;

    bool useProjectionDefault;
    if (map.containsKey('use_projection_as_default_target') &&
        map['use_projection_as_default_target'] != null) {
      useProjectionDefault =
          (map['use_projection_as_default_target'] as int) != 0;
    } else {
      final src = map['budget_source'] as String? ?? 'category';
      useProjectionDefault = src != 'category';
    }

    return AppSettings(
      appMode: AppMode.values.firstWhere(
        (e) => e.name == map['app_mode'],
        orElse: () => AppMode.combined,
      ),
      useProjectionAsDefaultTarget: useProjectionDefault,
      startingBalance: (map['starting_balance'] as num?)?.toDouble() ?? 0.0,
      safetyBuffer: (map['safety_buffer'] as num?)?.toDouble() ?? 0.0,
      currencySymbol: map['currency_symbol'] as String? ?? '\$',
      defaultProjectionMonths:
          map['default_projection_months'] as int? ?? 3,
      themeMode: ThemeModeSetting.values.firstWhere(
        (e) => e.name == map['theme_mode'],
        orElse: () => ThemeModeSetting.dark,
      ),
      showOverspendWarning: (map['show_overspend_warning'] as int?) == 1,
      showCurrencySymbol: (map['show_currency_symbol'] as int?) != 0,
      negativeFormat: NegativeFormat.values.firstWhere(
        (e) => e.name == (map['negative_format'] as String? ?? 'minus'),
        orElse: () => NegativeFormat.minus,
      ),
      lookbackMode: ProjectionLookbackMode.values.firstWhere(
        (e) => e.name == (map['lookback_mode'] as String? ?? 'monthStart'),
        orElse: () => ProjectionLookbackMode.monthStart,
      ),
      horizonMode: ProjectionHorizonMode.values.firstWhere(
        (e) => e.name == (map['horizon_mode'] as String? ?? 'eom'),
        orElse: () => ProjectionHorizonMode.eom,
      ),
      customLookbackStart: _parseDate(map['custom_lookback_start']),
      customHorizonEnd: _parseDate(map['custom_horizon_end']),
      rememberProjectionRange:
          (map['remember_projection_range'] as int?) != 0,
      projectionPaidFilter: ProjectionPaidFilter.values.firstWhere(
        (e) =>
            e.name == (map['projection_paid_filter'] as String? ?? 'all'),
        orElse: () => ProjectionPaidFilter.all,
      ),
      colorScheme: AppColorScheme.values.firstWhere(
        (e) => e.name == (map['color_scheme'] as String? ?? 'defaultBlue'),
        orElse: () => AppColorScheme.defaultBlue,
      ),
    );
  }

  Future<void> updateSettings(AppSettings settings) async {
    final db = await dbHelper.database;

    final effective = settings.appMode == AppMode.actuals
        ? settings.copyWith(useProjectionAsDefaultTarget: false)
        : settings;

    await db.update(
      'settings',
      {
        'app_mode': effective.appMode.name,
        'budget_source': effective.useProjectionAsDefaultTarget
            ? 'projection'
            : 'category',
        'use_projection_as_default_target':
            effective.useProjectionAsDefaultTarget ? 1 : 0,
        'starting_balance': effective.startingBalance,
        'safety_buffer': effective.safetyBuffer,
        'currency_symbol': effective.currencySymbol,
        'default_projection_months': effective.defaultProjectionMonths,
        'theme_mode': effective.themeMode.name,
        'show_overspend_warning': effective.showOverspendWarning ? 1 : 0,
        'show_currency_symbol': effective.showCurrencySymbol ? 1 : 0,
        'negative_format': effective.negativeFormat.name,
        'lookback_mode': effective.lookbackMode.name,
        'horizon_mode': effective.horizonMode.name,
        'custom_lookback_start': _dateToDb(effective.customLookbackStart),
        'custom_horizon_end': _dateToDb(effective.customHorizonEnd),
        'remember_projection_range':
            effective.rememberProjectionRange ? 1 : 0,
        'projection_paid_filter': effective.projectionPaidFilter.name,
        'color_scheme': effective.colorScheme.name,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}