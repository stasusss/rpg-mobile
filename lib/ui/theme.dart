import 'package:flutter/material.dart';

/// Palette for the whole app. Dark, warm and high contrast so the Flame
/// viewport and the control panels read as one piece.
abstract final class AppColors {
  static const Color background = Color(0xFF0F1017);
  static const Color surface = Color(0xFF191B26);
  static const Color surfaceAlt = Color(0xFF232635);
  static const Color surfaceHigh = Color(0xFF2C3042);
  static const Color outline = Color(0xFF343A50);

  static const Color gold = Color(0xFFF0B429);
  static const Color gem = Color(0xFF7DD3FC);
  static const Color xp = Color(0xFF8B5CF6);
  static const Color hp = Color(0xFFE5484D);
  static const Color mana = Color(0xFF818CF8);
  static const Color success = Color(0xFF4ADE80);
  static const Color info = Color(0xFF60A5FA);

  static const Color text = Color(0xFFE8EAF2);
  static const Color textMuted = Color(0xFF9AA1BA);
  static const Color textFaint = Color(0xFF666E88);
}

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.dark(
    surface: AppColors.background,
    primary: AppColors.gold,
    onPrimary: Color(0xFF241A00),
    secondary: AppColors.info,
    error: AppColors.hp,
    outline: AppColors.outline,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      bodyMedium: TextStyle(fontSize: 13, color: AppColors.text, height: 1.35),
      bodySmall: TextStyle(
        fontSize: 11.5,
        color: AppColors.textMuted,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        color: AppColors.textFaint,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outline,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.text, fontSize: 12.5),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
