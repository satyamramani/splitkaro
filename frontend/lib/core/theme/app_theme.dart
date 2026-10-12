import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand accent colors
  static const primaryColor = Color(0xFF818CF8); // Soft Electric Indigo
  static const primaryLight = Color(0xFFA5B4FC); // Indigo 300
  static const primaryDark = Color(0xFF6366F1);  // Indigo 500
  static const secondaryColor = Color(0xFF34D399); // Radiant Mint / Emerald (Positive balance)
  
  // Financial status colors
  static const errorColor = Color(0xFFFB7185);    // Modern Coral Rose (Debts / You owe)
  static const successColor = Color(0xFF34D399);  // Modern Emerald (Credits / You are owed)
  static const warningColor = Color(0xFFFBBF24);  // Warm Amber

  // Dark theme surface hierarchy (Deep Obsidian / Midnight Slate)
  static const darkBackground = Color(0xFF090B0E);     // Deepest canvas background
  static const darkSurface = Color(0xFF11141C);        // Primary surface (sheets, nav, dialogs, appbar)
  static const darkCard = Color(0xFF161A24);           // Elevated cards, feed items
  static const darkCardElevated = Color(0xFF1E2330);   // Higher elevation (inputs, inner containers, chips)
  static const darkBorder = Color(0xFF262C3D);         // Hairline card/component border
  static const darkBorderSubtle = Color(0xFF1A1F2C);   // Subtle divider/separator

  // Light theme surface colors (kept for consistency/fallback)
  static const backgroundColor = Color(0xFFF8FAFC);
  static const surfaceColor = darkCard; // Defaulting to darkCard so any legacy reference gets dark surface!

  // Text colors (Dark theme)
  static const textPrimaryColor = Color(0xFFF8FAFC);   // Slate 50 (High contrast)
  static const textSecondaryColor = Color(0xFF94A3B8); // Slate 400 (Readable muted)
  static const textMuted = Color(0xFF64748B);          // Slate 500 (Captions, timestamps)

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        primaryContainer: Color(0xFF312E81),
        secondary: secondaryColor,
        secondaryContainer: Color(0xFF064E3B),
        surface: darkSurface,
        surfaceContainerHighest: darkCard,
        surfaceContainerHigh: darkCardElevated,
        surfaceContainer: darkSurface,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Color(0xFF064E3B),
        onSurface: textPrimaryColor,
        onSurfaceVariant: textSecondaryColor,
        outline: darkBorder,
        outlineVariant: darkBorderSubtle,
      ),
      scaffoldBackgroundColor: darkBackground,
      fontFamily: GoogleFonts.outfit().fontFamily,
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorderSubtle,
        space: 1,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimaryColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: textSecondaryColor,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        modalBackgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryColor,
          side: const BorderSide(color: darkBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCardElevated,
        labelStyle: const TextStyle(color: textSecondaryColor, fontSize: 14),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimaryColor),
        titleTextStyle: TextStyle(
          color: textPrimaryColor,
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        height: 66,
        indicatorColor: primaryColor.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primaryLight,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryLight, size: 23);
          }
          return const IconThemeData(color: textMuted, size: 22);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textSecondaryColor,
        textColor: textPrimaryColor,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.all(Colors.white),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return darkCardElevated;
        }),
        side: const BorderSide(color: darkBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      iconTheme: const IconThemeData(color: textSecondaryColor),
      popupMenuTheme: PopupMenuThemeData(
        color: darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder),
        ),
        textStyle: const TextStyle(color: textPrimaryColor),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCardElevated,
        contentTextStyle: const TextStyle(color: textPrimaryColor, fontSize: 13.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        selectedColor: primaryColor,
        disabledColor: darkSurface,
        labelStyle: const TextStyle(color: textPrimaryColor, fontSize: 12.5),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 12.5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: darkBorder),
        ),
      ),
    );
  }

  // Fallback Light Theme
  static ThemeData get lightTheme => darkTheme;
}
