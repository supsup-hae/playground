import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/tokens.dart';

/// 앱 전체 테마. 색과 모서리는 [AppColors]·[AppRadius] 에서만 가져온다.
ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.background,
    secondary: AppColors.accent,
    onSecondary: AppColors.background,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.surfaceRaised,
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
    error: AppColors.danger,
    onError: AppColors.background,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.line,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: shape.copyWith(side: const BorderSide(color: AppColors.line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: shape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.line),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.background,
      indicatorColor: AppColors.surfaceRaised,
      selectedIconTheme: IconThemeData(color: AppColors.accent),
      unselectedIconTheme: IconThemeData(color: AppColors.textMuted),
      selectedLabelTextStyle: TextStyle(color: AppColors.accent),
      unselectedLabelTextStyle: TextStyle(color: AppColors.textMuted),
    ),
  );
}
