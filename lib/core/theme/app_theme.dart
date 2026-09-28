import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF111214);
  static const deepInk = Color(0xFF0B0C0E);
  static const panel = Color(0xFF1B1D21);
  static const line = Color(0xFF303237);
  static const muted = Color(0xFF9A9CA3);
  static const warm = Color(0xFFFFB983);
  static const warmDark = Color(0xFF30231B);
  static const lightCanvas = Color(0xFFF5F3F0);
  static const lightPanel = Color(0xFFFFFFFF);
}

abstract final class AppTheme {
  static ThemeData dark({Color? dynamicAccent}) =>
      _build(Brightness.dark, dynamicAccent: dynamicAccent);
  static ThemeData light({Color? dynamicAccent}) =>
      _build(Brightness.light, dynamicAccent: dynamicAccent);

  static ThemeData _build(Brightness brightness, {Color? dynamicAccent}) {
    final isDark = brightness == Brightness.dark;
    final fallback = ColorScheme.fromSeed(
      seedColor: dynamicAccent ?? AppColors.warm,
      brightness: brightness,
      surface: isDark ? AppColors.ink : AppColors.lightCanvas,
    );
    final scheme = fallback.copyWith(
      primary: dynamicAccent == null
          ? isDark
                ? AppColors.warm
                : const Color(0xFF8B4C21)
          : fallback.primary,
      onPrimary: dynamicAccent == null
          ? isDark
                ? const Color(0xFF28170B)
                : Colors.white
          : fallback.onPrimary,
      secondary: dynamicAccent == null
          ? isDark
                ? const Color(0xFFC6B7D9)
                : const Color(0xFF665878)
          : fallback.secondary,
      surface: isDark ? AppColors.ink : AppColors.lightCanvas,
      surfaceContainerLow: isDark
          ? const Color(0xFF151619)
          : const Color(0xFFF0EDEA),
      surfaceContainer: isDark ? AppColors.panel : AppColors.lightPanel,
      outlineVariant: isDark ? AppColors.line : const Color(0xFFE4DFDA),
    );
    final text = Typography.material2021().white;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.deepInk
          : AppColors.lightCanvas,
      textTheme:
          (isDark
                  ? Typography.material2021().white
                  : Typography.material2021().black)
              .apply(fontFamily: 'Arial'),
      iconTheme: IconThemeData(color: isDark ? Colors.white70 : Colors.black54),
      dividerColor: scheme.outlineVariant,
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF292B30) : const Color(0xFF25262A),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: text.bodySmall?.copyWith(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1B1F) : Colors.white,
        hintStyle: TextStyle(color: isDark ? AppColors.muted : Colors.black45),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: .8),
            width: 1.2,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
