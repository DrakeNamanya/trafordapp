import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color trafordOrange = Color(0xFFF15A24); // Primary
  static const Color growthGreen = Color(0xFF22B14C);   // Secondary
  static const Color softLeaf = Color(0xFF8CC63F);      // Accent

  // Other UI Colors
  static const Color bgGray = Color(0xFFF9FAFB);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color starYellow = Color(0xFFFACC15);
  
  // Status Colors (kept similar but maybe tweaked to match brand if needed)
  static const Color statusPending = Color(0xFFFEF3C7);
  static const Color statusProcessing = Color(0xFFDBEAFE);
  static const Color statusShipped = Color(0xFFEDE9FE);
  static const Color statusDelivered = Color(0xFFDCFCE7); // Maybe use softLeaf with opacity? Keeping as is for now.
  static const Color statusCancelled = Color(0xFFFEE2E2);

  // Legacy mappings to make migration easier if needed, but we will replace them.
  // We will refrain from using these and update the code to use the specific brand colors.

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: trafordOrange,
        brightness: Brightness.light,
        scaffoldBackgroundColor: bgGray,
        appBarTheme: const AppBarTheme(
          backgroundColor: trafordOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: trafordOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: trafordOrange,
            side: const BorderSide(color: trafordOrange),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: trafordOrange,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: trafordOrange, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: cardBorder),
          ),
          margin: EdgeInsets.zero,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: trafordOrange,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 12),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: trafordOrange,
          labelStyle: const TextStyle(fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: cardBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
}
