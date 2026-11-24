
import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  // Kept for existing call sites.
  static const seed = AppColors.indigo;
  static const gold = AppColors.gold;
  static const online = AppColors.success;
  static const busy = AppColors.busy;
  static const offline = AppColors.offline;

  static const serif = 'PlayfairDisplay';
  static const sans = 'DMSans';

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.indigo,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.indigo,
      onPrimary: Colors.white,
      primaryContainer: AppColors.lavender,
      onPrimaryContainer: AppColors.indigoDeep,
      secondary: AppColors.saffron,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.saffronSoft,
      onSecondaryContainer: const Color(0xFF6B3A00),
      surface: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF6F2EA),
      surfaceContainer: const Color(0xFFF3EEE5),
      surfaceContainerHigh: const Color(0xFFEFE9DF),
      surfaceContainerHighest: const Color(0xFFE9E2D6),
      outline: AppColors.offline,
      outlineVariant: AppColors.hairline,
      error: AppColors.danger,
      errorContainer: const Color(0xFFFCE4E7),
      onErrorContainer: const Color(0xFF7A1F2B),
    );

    final base = Typography.material2021().black.apply(
          fontFamily: sans,
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        );

    TextStyle serifStyle(double size, {double height = 1.2, double spacing = -.2}) =>
        TextStyle(
          fontFamily: serif,
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: height,
          letterSpacing: spacing,
          color: AppColors.ink,
          fontFeatures: const [FontFeature.liningFigures()],
        );

    final text = base.copyWith(
      displaySmall: serifStyle(34, height: 1.1),
      headlineLarge: serifStyle(30, height: 1.15),
      headlineMedium: serifStyle(26, height: 1.15),
      headlineSmall: serifStyle(22, height: 1.2),
      titleLarge: serifStyle(20, height: 1.25, spacing: 0),
      titleMedium: base.titleMedium?.copyWith(
          fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0),
      titleSmall: base.titleSmall?.copyWith(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: base.bodySmall
          ?.copyWith(fontSize: 12.5, height: 1.4, color: AppColors.muted),
      labelLarge: base.labelLarge
          ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: .1),
      labelMedium: base.labelMedium
          ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .1),
      labelSmall: base.labelSmall
          ?.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .2),
    );

    final radius = BorderRadius.circular(16);
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: radius, borderSide: BorderSide(color: c, width: w));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      fontFamily: sans,
      scaffoldBackgroundColor: AppColors.ivory,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: border(AppColors.hairline),
        enabledBorder: border(AppColors.hairline),
        focusedBorder: border(AppColors.indigo, 1.6),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 1.6),
        hintStyle: const TextStyle(color: AppColors.offline),
        labelStyle: const TextStyle(color: AppColors.muted),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.indigo,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.hairline,
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(
              fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.indigo,
          minimumSize: const Size(64, 50),
          side: const BorderSide(color: AppColors.hairline, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(
              fontFamily: sans, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.indigo,
          textStyle: const TextStyle(
              fontFamily: sans, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.indigo,
        side: const BorderSide(color: AppColors.hairline),
        showCheckmark: false,
        labelStyle: const TextStyle(
            fontFamily: sans, fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink),
        secondaryLabelStyle: const TextStyle(
            fontFamily: sans, fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.lavender,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: sans,
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? AppColors.indigo : AppColors.muted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected) ? AppColors.indigo : AppColors.muted,
            )),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.hairline, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(fontFamily: sans, color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.titleLarge,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.indigo),
    );
  }
}
