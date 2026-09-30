import 'package:flutter/material.dart';

const kBg = Color(0xFF1a1b2e);
const kSurface = Color(0xFF242636);
const kSurface2 = Color(0xFF2e3048);
const kBorder = Color(0xFF3d3f5a);
const kPurple = Color(0xFFc084fc);
const kMuted = Color(0xFF9a9ab0);
const kGreen = Color(0xFF4ade80);
const kOrange = Color(0xFFfb923c);
const kRed = Color(0xFFf87171);
const kText = Color(0xFFe2e2f0);

ThemeData appTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      surface: kBg,
      primary: kPurple,
      onPrimary: kBg,
      secondary: kSurface,
      onSurface: kText,
    ),
    scaffoldBackgroundColor: kBg,
    cardColor: kSurface,
    dividerColor: kBorder,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: kText),
      bodySmall: TextStyle(color: kMuted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kPurple),
      ),
      labelStyle: const TextStyle(color: kMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPurple,
        foregroundColor: kBg,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPurple,
        side: const BorderSide(color: kBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? kBg : kMuted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? kPurple : kBorder),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: kPurple.withValues(alpha: 0.2),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
        color: s.contains(WidgetState.selected) ? kPurple : kMuted,
      )),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
        color: s.contains(WidgetState.selected) ? kPurple : kMuted,
        fontSize: 12,
        fontWeight: s.contains(WidgetState.selected)
            ? FontWeight.w600
            : FontWeight.normal,
      )),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurface,
      foregroundColor: kText,
      elevation: 0,
      titleTextStyle: TextStyle(
          color: kText, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kSurface2,
      contentTextStyle: TextStyle(color: kText),
    ),
  );
}

Color pctColor(double pct) {
  if (pct >= 80) return kGreen;
  if (pct >= 50) return kOrange;
  return kRed;
}
