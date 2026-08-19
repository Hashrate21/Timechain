import 'package:flutter/material.dart';

import '../../domain/entities/app_settings.dart';

class AppColors {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color primary;
  final Color cyan;
  final Color purple;
  final Color successColor;
  final Color dangerColor;
  final Color warningColor;
  final Color textPrimary;
  final Color textSecondary;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.primary,
    required this.cyan,
    required this.purple,
    required this.successColor,
    required this.dangerColor,
    required this.warningColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  // ---------- Legacy statics (existing screens keep working) ----------
  static const darkBackground = Color(0xFF12141C);
  static const darkSurface = Color(0xFF1A1D27);
  static const darkSurfaceElevated = Color(0xFF22252F);
  static const darkBorder = Color(0xFF2A2E3A);

  static const lightBackground = Color(0xFFD5D9DF);
  static const lightSurface = Color(0xFFDFE3E7);
  static const lightSurfaceElevated = Color(0xFFF8F9FA);
  static const lightBorder = Color(0xFFD0D5DD);

  static const primaryBlue = Color(0xFF3B82F6);
  static const primaryCyan = Color(0xFF06B6D4);
  static const accentPurple = Color(0xFF8B5CF6);
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  static const textPrimaryDark = Color(0xFFF8FAFC);
  static const textSecondaryDark = Color(0xFF94A3B8);
  static const textPrimaryLight = Color(0xFF0F172A);
  static const textSecondaryLight = Color(0xFF64748B);

  static const primaryGradient = LinearGradient(
    colors: [primaryBlue, primaryCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const purpleGradient = LinearGradient(
    colors: [accentPurple, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color chipBorder(bool isDark) =>
      isDark ? const Color(0xFF3A3F4B) : const Color(0xFFB8BFC9);

  static Color chipBorderSelected(bool isDark) =>
      primaryBlue.withValues(alpha: isDark ? 0.7 : 0.9);

  // ---------- Scheme-aware API ----------
  static AppColors of(BuildContext context, {AppColorScheme? scheme}) {
    final brightness = Theme.of(context).brightness;
    final effectiveScheme =
        scheme ??
        Theme.of(context).extension<AppColorsExtension>()?.scheme ??
        AppColorScheme.defaultBlue;
    return forScheme(effectiveScheme, brightness);
  }

  static AppColors forScheme(AppColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    switch (scheme) {
      case AppColorScheme.defaultBlue:
        return isDark ? _defaultDark : _defaultLight;
      case AppColorScheme.neonNights:
        return isDark ? _neonDark : _neonLight;
      case AppColorScheme.orange:
        return isDark ? _bitcoinDark : _bitcoinLight;
      case AppColorScheme.mono:
        return isDark ? _monoDark : _monoLight;
    }
  }

  // ===== Default Blue =====
  static const _defaultDark = AppColors(
    background: Color(0xFF12141C),
    surface: Color(0xFF1A1D27),
    surfaceElevated: Color(0xFF22252F),
    border: Color(0xFF2A2E3A),
    primary: Color(0xFF3B82F6),
    cyan: Color(0xFF06B6D4),
    purple: Color(0xFF8B5CF6),
    successColor: Color(0xFF10B981),
    dangerColor: Color(0xFFEF4444),
    warningColor: Color(0xFFF59E0B),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
  );

  static const _defaultLight = AppColors(
    background: Color(0xFFD5D9DF),
    surface: Color(0xFFDFE3E7),
    surfaceElevated: Color(0xFFF8F9FA),
    border: Color(0xFFD0D5DD),
    primary: Color(0xFF3B82F6),
    cyan: Color(0xFF06B6D4),
    purple: Color(0xFF8B5CF6),
    successColor: Color(0xFF10B981),
    dangerColor: Color(0xFFEF4444),
    warningColor: Color(0xFFF59E0B),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
  );

  // ===== Tokyo Neon Nights =====
  static const _neonDark = AppColors(
    background: Color(0xFF0B0B12),
    surface: Color(0xFF151521),
    surfaceElevated: Color(0xFF1E1E2E),
    border: Color(0xFF24e6ec),
    primary: Color(0xFFc91bc9),
    cyan: Color(0xFF24e6ec),
    purple: Color(0xFFBF5AF2),
    successColor: Color(0xFF39FF14),
    dangerColor: Color(0xFFFF2E63),
    warningColor: Color(0xFFf1cb0a),
    textPrimary: Color(0xFFF8F8FF),
    textSecondary: Color(0xFFA0A0C0),
  );

  static const _neonLight = AppColors(
    background: Color(0xFFF0F4FF),
    surface: Color(0xFFE8EEFF),
    surfaceElevated: Color(0xFFffffff),
    border: Color(0xFFea44f0),
    primary: Color(0xFF00B8D9),
    cyan: Color(0xFFE91E8C),
    purple: Color(0xFF9C27B0),
    successColor: Color(0xFF00C853),
    dangerColor: Color(0xFFD50000),
    warningColor: Color(0xFFFFAB00),
    textPrimary: Color(0xFF0A0A1A),
    textSecondary: Color(0xFF4A4A6A),
  );

  // ===== Placeholder 1 — Bitcoin orange =====
  static const _bitcoinDark = AppColors(
    background: Color(0xFF0f0f0f),
    surface: Color(0xFF0a0a0a),
    surfaceElevated: Color(0xFF000000),
    border: Color(0xFFff9100),
    primary: Color(0xFFd67f15), // classic BTC orange
    cyan: Color(0xFFFFB84D), // lighter orange highlight
    purple: Color(0xFFE87B0E), // deeper orange accent
    successColor: Color(0xFF22C55E),
    dangerColor: Color(0xFFEF4444),
    warningColor: Color(0xFFF59E0B),
    textPrimary: Color(0xFFFFF7ED),
    textSecondary: Color(0xFFA8A29E),
  );

  static const _bitcoinLight = AppColors(
    background: Color(0xFFfdf8f3),
    surface: Color(0xFFfffdfa),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFF777575),
    primary: Color(0xFFE8840C), // slightly deeper for contrast on light
    cyan: Color(0xFFF7931A),
    purple: Color(0xFFC2410C),
    successColor: Color(0xFF16A34A),
    dangerColor: Color(0xFFDC2626),
    warningColor: Color(0xFFD97706),
    textPrimary: Color(0xFF1C1917),
    textSecondary: Color(0xFF78716C),
  );
  // ===== Placeholder 2 — Pure mono (grey / charcoal) =====
  static const _monoDark = AppColors(
    background: Color(0xFF0C0C0C),
    surface: Color(0xFF161616),
    surfaceElevated: Color(0xFF1F1F1F),
    border: Color(0xFF2E2E2E),
    primary: Color(0xFFa8a3a3), // light grey as accent on dark
    cyan: Color(0xFFA3A3A3), // mid grey secondary
    purple: Color(0xFF737373), // muted tertiary
    successColor: Color(0xFF22C55E), // keep readable utilities
    dangerColor: Color(0xFFEF4444),
    warningColor: Color(0xFFF59E0B),
    textPrimary: Color(0xFFececec),
    textSecondary: Color(0xFFc2bfbf),
  );

  static const _monoLight = AppColors(
    background: Color.fromARGB(
      255,
      207,
      201,
      201,
    ), // grey offset (not blue-grey)
    surface: Color(0xFFF2F2F2),
    surfaceElevated: Color(0xFFf7f7f7),
    border: Color(0xFFa1a1a1),
    primary: Color(0xFF171717), // near-black accent on light
    cyan: Color(0xFF525252),
    purple: Color(0xFF737373),
    successColor: Color(0xFF16A34A),
    dangerColor: Color(0xFFDC2626),
    warningColor: Color(0xFFD97706),
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFFb4b3b3),
  );
}

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final AppColorScheme scheme;

  const AppColorsExtension({required this.scheme});

  @override
  AppColorsExtension copyWith({AppColorScheme? scheme}) {
    return AppColorsExtension(scheme: scheme ?? this.scheme);
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return t < 0.5 ? this : other;
  }
}
