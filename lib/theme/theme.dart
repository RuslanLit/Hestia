import 'package:flutter/material.dart';

class HestiaColors {
  const HestiaColors._();

  static const primaryLight = Color(0xFF3B82C4);
  static const primaryHoverLight = Color(0xFF2F73B4);
  static const primaryActiveLight = Color(0xFF285F95);
  static const primarySoftLight = Color(0xFFD8ECFF);

  static const backgroundLight = Color(0xFFFAF7F2);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceStrongLight = Color(0xFFF4ECE3);
  static const borderLight = Color(0xFFE4D8CC);
  static const textPrimaryLight = Color(0xFF1F2933);
  static const textSecondaryLight = Color(0xFF5F6B7A);

  static const primaryDark = Color(0xFF7DB7F0);
  static const primaryHoverDark = Color(0xFF94C5F4);
  static const primaryActiveDark = Color(0xFFD9ECFF);
  static const primarySoftDark = Color(0xFF223A50);

  static const backgroundDark = Color(0xFF171A1F);
  static const surfaceDark = Color(0xFF222832);
  static const surfaceStrongDark = Color(0xFF2B3340);
  static const borderDark = Color(0xFF3A4350);
  static const textPrimaryDark = Color(0xFFF5F1EA);
  static const textSecondaryDark = Color(0xFFC8C1B8);

  static const success = Color(0xFF4CA97A);
  static const warning = Color(0xFFE2A146);
  static const error = Color(0xFFD46F6F);
  static const info = Color(0xFF4E92D2);
}

class HestiaSpacing {
  const HestiaSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const huge = 64.0;
}

class HestiaTypography {
  const HestiaTypography._();

  static const fontFamily = 'Inter';
  static const fallbackFonts = <String>[
    'Segoe UI',
    'Roboto',
    'Arial',
    'sans-serif',
  ];

  static const h1 = TextStyle(
    fontSize: 40,
    height: 1.08,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );
  static const h2 = TextStyle(
    fontSize: 32,
    height: 1.12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );
  static const h3 = TextStyle(
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  static const body = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const small = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
}

@immutable
class HestiaStateColors extends ThemeExtension<HestiaStateColors> {
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  const HestiaStateColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  static const defaults = HestiaStateColors(
    success: HestiaColors.success,
    warning: HestiaColors.warning,
    error: HestiaColors.error,
    info: HestiaColors.info,
  );

  @override
  HestiaStateColors copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
  }) {
    return HestiaStateColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
    );
  }

  @override
  HestiaStateColors lerp(ThemeExtension<HestiaStateColors>? other, double t) {
    if (other is! HestiaStateColors) {
      return this;
    }
    return HestiaStateColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        primary: HestiaColors.primaryLight,
        primaryHover: HestiaColors.primaryHoverLight,
        primaryActive: HestiaColors.primaryActiveLight,
        primarySoft: HestiaColors.primarySoftLight,
        background: HestiaColors.backgroundLight,
        surface: HestiaColors.surfaceLight,
        surfaceStrong: HestiaColors.surfaceStrongLight,
        border: HestiaColors.borderLight,
        textPrimary: HestiaColors.textPrimaryLight,
        textSecondary: HestiaColors.textSecondaryLight,
      );

  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        primary: HestiaColors.primaryDark,
        primaryHover: HestiaColors.primaryHoverDark,
        primaryActive: HestiaColors.primaryActiveDark,
        primarySoft: HestiaColors.primarySoftDark,
        background: HestiaColors.backgroundDark,
        surface: HestiaColors.surfaceDark,
        surfaceStrong: HestiaColors.surfaceStrongDark,
        border: HestiaColors.borderDark,
        textPrimary: HestiaColors.textPrimaryDark,
        textSecondary: HestiaColors.textSecondaryDark,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color primaryHover,
    required Color primaryActive,
    required Color primarySoft,
    required Color background,
    required Color surface,
    required Color surfaceStrong,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: isDark ? HestiaColors.backgroundDark : Colors.white,
      secondary: HestiaColors.success,
      onSecondary: isDark ? HestiaColors.backgroundDark : Colors.white,
      tertiary: HestiaColors.warning,
      onTertiary: Colors.white,
      error: HestiaColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
    ).copyWith(
      primaryContainer: primarySoft,
      onPrimaryContainer: primaryActive,
      secondaryContainer: primarySoft,
      onSecondaryContainer: primaryActive,
      tertiaryContainer: isDark
          ? HestiaColors.warning.withValues(alpha: 0.22)
          : const Color(0xFFFFE8CF),
      onTertiaryContainer:
          isDark ? const Color(0xFFFFE8CF) : const Color(0xFF6A4515),
      outline: border,
      onSurfaceVariant: textSecondary,
      surfaceContainerHighest: surfaceStrong,
      surfaceContainerHigh: surfaceStrong,
      surfaceContainer: surfaceStrong,
      surfaceTint: Colors.transparent,
    );

    final textTheme = _textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: HestiaTypography.fontFamily,
      fontFamilyFallback: HestiaTypography.fallbackFonts,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: const [HestiaStateColors.defaults],
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: primary,
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        dividerColor: border,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceStrong,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HestiaSpacing.lg,
          vertical: HestiaSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? HestiaColors.backgroundDark : Colors.white,
          disabledBackgroundColor: surfaceStrong,
          disabledForegroundColor: textSecondary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: HestiaSpacing.xl),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: isDark ? HestiaColors.backgroundDark : Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? HestiaColors.backgroundDark : Colors.white,
          disabledBackgroundColor: surfaceStrong,
          disabledForegroundColor: textSecondary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: HestiaSpacing.xl),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return primaryActive.withValues(alpha: 0.18);
            }
            if (states.contains(WidgetState.hovered)) {
              return primaryHover.withValues(alpha: 0.12);
            }
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: HestiaSpacing.xl),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Color.alphaBlend(
          HestiaColors.info.withValues(alpha: isDark ? 0.24 : 0.12),
          surface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: textPrimary,
          height: 1.35,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 10,
        insetPadding: const EdgeInsets.all(HestiaSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: HestiaColors.info.withValues(alpha: 0.24)),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      badgeTheme: BadgeThemeData(
        backgroundColor: HestiaColors.error,
        textColor: Colors.white,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    );
  }

  static TextTheme _textTheme(Color textPrimary, Color textSecondary) {
    return TextTheme(
      displayLarge: HestiaTypography.h1.copyWith(color: textPrimary),
      headlineMedium: HestiaTypography.h2.copyWith(color: textPrimary),
      titleLarge: HestiaTypography.h3.copyWith(color: textPrimary),
      bodyLarge: HestiaTypography.body.copyWith(color: textPrimary),
      bodyMedium: HestiaTypography.body.copyWith(color: textPrimary),
      bodySmall: HestiaTypography.small.copyWith(color: textSecondary),
      labelLarge: HestiaTypography.small.copyWith(
        color: textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}


