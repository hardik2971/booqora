import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette sampled from Booqora.png.
class AppColors {
  static const primary = Color(0xFF6431DD); // logo violet
  static const primaryDeep = Color(0xFF351DB1); // logo indigo
  static const primarySoft = Color(0xFFEFE9FD);
  static const lavender = Color(0xFFC2A3F9); // logo swoosh
  static const ink = Color(0xFF1C0938); // wordmark
  static const inkSoft = Color(0xFF4B3F66);
  static const muted = Color(0xFF7A7090);
  static const border = Color(0xFFE6E1F0);
  static const bg = Color(0xFFF7F5FC);
  static const surface = Colors.white;
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFE7F7ED);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFEF3E2);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFDECEC);
  static const info = Color(0xFF2563EB);
  static const infoSoft = Color(0xFFE8F0FE);

  static const brandGradient = LinearGradient(
    colors: [Color(0xFF7B3FF2), primary, primaryDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF1C0938), Color(0xFF2B1270), Color(0xFF351DB1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static TextTheme _text() {
    final body = GoogleFonts.interTextTheme();
    TextStyle? head(TextStyle? s) =>
        GoogleFonts.plusJakartaSans(textStyle: s, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.2);
    return body
        .copyWith(
          displayLarge: head(body.displayLarge),
          displayMedium: head(body.displayMedium),
          displaySmall: head(body.displaySmall),
          headlineLarge: head(body.headlineLarge),
          headlineMedium: head(body.headlineMedium),
          headlineSmall: head(body.headlineSmall),
          titleLarge: head(body.titleLarge)?.copyWith(fontSize: 20),
          titleMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink),
          titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.ink),
        )
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.primaryDeep,
      surface: AppColors.surface,
      error: AppColors.danger,
    );
    final radius = BorderRadius.circular(10);
    OutlineInputBorder ob(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c, width: w));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: _text(),
      dividerColor: AppColors.border,
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1, thickness: 1),
      splashFactory: InkSparkle.splashFactory,
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: ob(AppColors.border),
        enabledBorder: ob(AppColors.border),
        focusedBorder: ob(AppColors.primary, 1.6),
        errorBorder: ob(AppColors.danger),
        focusedErrorBorder: ob(AppColors.danger, 1.6),
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: AppColors.muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primarySoft,
        labelStyle: const TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w500),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: const BorderSide(color: Color(0xFFBFB6D3), width: 1.4),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.primary : const Color(0xFFD6D0E3)),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.border,
        labelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(8)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
