import 'package:equatable/equatable.dart';

enum AppMode { projection, actuals, combined }

enum ThemeModeSetting { system, light, dark }

enum NegativeFormat { minus, parentheses }

/// Projection timeline — how far back the range starts.
enum ProjectionLookbackMode { monthStart, lastPay, custom }

/// Projection timeline — how far forward the range ends.
enum ProjectionHorizonMode { eom, nextPay, custom }

enum ProjectionPaidFilter { all, unpaid, paid }

enum AppColorScheme { defaultBlue, neonNights, orange, mono }

class AppSettings extends Equatable {
  final AppMode appMode;

  /// When true: category target = manual Set if present, else that month's projection.
  /// When false: only manual Set amounts count (else 0).
  final bool useProjectionAsDefaultTarget;

  final double startingBalance;
  final double safetyBuffer;
  final String currencySymbol;
  final int defaultProjectionMonths;
  final ThemeModeSetting themeMode;
  final bool showOverspendWarning;
  final bool showCurrencySymbol;
  final NegativeFormat negativeFormat;

  final ProjectionLookbackMode lookbackMode;
  final ProjectionHorizonMode horizonMode;
  final DateTime? customLookbackStart;
  final DateTime? customHorizonEnd;
  final bool rememberProjectionRange;
  final ProjectionPaidFilter projectionPaidFilter;

  final AppColorScheme colorScheme;

  const AppSettings({
    this.appMode = AppMode.combined,
    this.useProjectionAsDefaultTarget = true,
    this.startingBalance = 0.0,
    this.safetyBuffer = 0.0,
    this.currencySymbol = '\$',
    this.defaultProjectionMonths = 3,
    this.themeMode = ThemeModeSetting.dark,
    this.showOverspendWarning = true,
    this.showCurrencySymbol = true,
    this.negativeFormat = NegativeFormat.minus,
    this.lookbackMode = ProjectionLookbackMode.monthStart,
    this.horizonMode = ProjectionHorizonMode.eom,
    this.customLookbackStart,
    this.customHorizonEnd,
    this.rememberProjectionRange = true,
    this.projectionPaidFilter = ProjectionPaidFilter.all,
    this.colorScheme = AppColorScheme.defaultBlue,
  });

  AppSettings copyWith({
    AppMode? appMode,
    bool? useProjectionAsDefaultTarget,
    double? startingBalance,
    double? safetyBuffer,
    String? currencySymbol,
    int? defaultProjectionMonths,
    ThemeModeSetting? themeMode,
    bool? showOverspendWarning,
    bool? showCurrencySymbol,
    NegativeFormat? negativeFormat,
    ProjectionLookbackMode? lookbackMode,
    ProjectionHorizonMode? horizonMode,
    DateTime? customLookbackStart,
    DateTime? customHorizonEnd,
    bool? rememberProjectionRange,
    ProjectionPaidFilter? projectionPaidFilter,
    AppColorScheme? colorScheme,
    bool clearCustomLookbackStart = false,
    bool clearCustomHorizonEnd = false,
  }) {
    return AppSettings(
      appMode: appMode ?? this.appMode,
      useProjectionAsDefaultTarget:
          useProjectionAsDefaultTarget ?? this.useProjectionAsDefaultTarget,
      startingBalance: startingBalance ?? this.startingBalance,
      safetyBuffer: safetyBuffer ?? this.safetyBuffer,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      defaultProjectionMonths:
          defaultProjectionMonths ?? this.defaultProjectionMonths,
      themeMode: themeMode ?? this.themeMode,
      showOverspendWarning: showOverspendWarning ?? this.showOverspendWarning,
      showCurrencySymbol: showCurrencySymbol ?? this.showCurrencySymbol,
      negativeFormat: negativeFormat ?? this.negativeFormat,
      lookbackMode: lookbackMode ?? this.lookbackMode,
      horizonMode: horizonMode ?? this.horizonMode,
      customLookbackStart: clearCustomLookbackStart
          ? null
          : (customLookbackStart ?? this.customLookbackStart),
      customHorizonEnd: clearCustomHorizonEnd
          ? null
          : (customHorizonEnd ?? this.customHorizonEnd),
      rememberProjectionRange:
          rememberProjectionRange ?? this.rememberProjectionRange,
      projectionPaidFilter: projectionPaidFilter ?? this.projectionPaidFilter,
      colorScheme: colorScheme ?? this.colorScheme,
    );
  }

  @override
  List<Object?> get props => [
    appMode,
    useProjectionAsDefaultTarget,
    startingBalance,
    safetyBuffer,
    currencySymbol,
    defaultProjectionMonths,
    themeMode,
    showOverspendWarning,
    showCurrencySymbol,
    negativeFormat,
    lookbackMode,
    horizonMode,
    customLookbackStart,
    customHorizonEnd,
    rememberProjectionRange,
    projectionPaidFilter,
    colorScheme,
  ];
}
