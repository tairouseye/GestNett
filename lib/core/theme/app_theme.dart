import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.g600,
      primary: AppColors.g600,
      onPrimary: AppColors.white,
      secondary: AppColors.g400,
      surface: AppColors.white,
      onSurface: AppColors.s900,
      background: AppColors.background,
      error: AppColors.red,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.g900,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.s100),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.s50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.s200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.s200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.g500, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.s400),
      hintStyle: const TextStyle(color: AppColors.s300),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.g600,
        foregroundColor: AppColors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.g600),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.g600,
      foregroundColor: AppColors.white,
      elevation: 4,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.s100,
      thickness: 1,
      space: 1,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.g600,
      unselectedItemColor: AppColors.s300,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.s50,
      labelStyle: const TextStyle(fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.s900),
      headlineMedium: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.s900),
      headlineSmall: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.s900),
      titleLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.s900),
      titleMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.s900),
      bodyLarge: TextStyle(fontSize: 15, color: AppColors.s900),
      bodyMedium: TextStyle(fontSize: 13, color: AppColors.s700),
      bodySmall: TextStyle(fontSize: 11, color: AppColors.s400),
      labelLarge: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.s900),
    ),
  );
}
