// lib/ui/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  // --- Teal (Primary) ---
  static const Color teal500 = Color(0xFF14B8A6);
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal100 = Color(0xFFCCFBF1);
  static const Color teal200 = Color(0xFF99F6E4);
  static const Color teal300 = Color(0xFF5EEAD4);
  static const Color teal50 = Color(0xFFF0FDFA);

  // --- Purple (Secondary) ---
  static const Color purple500 = Color(0xFFA855F7);
  static const Color purple600 = Color(0xFF9333EA);
  static const Color purple100 = Color(0xFFE9D5FF);
  static const Color purple200 = Color(0xFFD8B4FE);
  static const Color purple300 = Color(0xFFC084FC);
  static const Color purple50 = Color(0xFFF5F3FF);

  // --- Neutrals ---
  static const Color white = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFE5E5E5);
  static const Color neutral300 = Color(0xFFD4D4D4);
  static const Color neutral400 = Color(0xFFBDBDBD);
  static const Color neutral500 = Color(0xFF737373);
  static const Color neutral600 = Color(0xFF525252);
  static const Color neutral700 = Color(0xFF404040);
  static const Color neutral800 = Color(0xFF262626);
  static const Color neutral900 = Color(0xFF171717);

  // --- Supporting ---
  static const Color destructive = Color(0xFFD4183D);
  static const Color mutedFg = Color(0xFF717182);
  static const Color mutedBg = Color(0xFFECECF0);
  static const Color accentBg = Color(0xFFE9EBEF);

  static const Color inputBg = Color(0xFFF3F3F5);
  static const Color switchBg = Color(0xFFCBCED4);
  static const Color borderFade = Color(0x1A000000);

    /// Accent Background
  static const Color e9ebef = Color(0xFFE9EBEF);

  /// Input Background (very light neutral)
  static const Color f3 = Color(0xFFF3F3F5);
  static const Color f5 = Color(0xFFF3F3F5);
  
}

class AppRadius {
  static const double card = 16;
  static const double chip = 12;
  static const double pill = 999;
  static const double sheet = 24;
}

// --- Shadows ---------------------------------------------------------------
class AppShadows {
  // subtle, floaty
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x14000000), // ~8% black
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static final small = <BoxShadow>[
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // default for cards in the mock
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x1A000000), // ~10% black
      blurRadius: 18,
      spreadRadius: 1,
      offset: Offset(0, 8),
    ),
  ];

  // elevated surfaces / sticky bars
  static const List<BoxShadow> strong = [
    BoxShadow(
      color: Color(0x26000000), // ~15% black
      blurRadius: 28,
      spreadRadius: 2,
      offset: Offset(0, 12),
    ),
  ];
}

class AppGradients {
  // ✅ const, so you can do: const BoxDecoration(gradient: AppGradients.pageBg)
  // 35% opacity baked into ARGB (0x59 = 89 / 255)
  static const Gradient pageBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x59F0FDFA), // teal50 @ 35% opacity
      Color(0x59F5F3FF), // purple50 @ 35% opacity
    ],
  );

  // CTA gradient (unchanged)
  static const Gradient cta = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.teal500, AppColors.purple500],
  );

  static const Gradient goalCard = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.teal500, AppColors.purple500],
  );
}

// --- Decorations (helpers to avoid repetition) -----------------------------
class AppDecor {
  /// Card surface with optional gradient.
  /// NOTE: This returns a **non-const** decoration so you can pass dynamic colors.
  static BoxDecoration card({
    Color color = AppColors.white,
    Gradient? gradient,
    List<BoxShadow> boxShadow = AppShadows.soft,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(16)),
    Border? border,
  }) {
    return BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
      border: border ?? Border.all(color: AppColors.neutral200),
    );
  }

  /// Small pill / chip background.
  static BoxDecoration pill({
    Color color = AppColors.accentBg, // Accent Background from your palette
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(999)),
  }) {
    return BoxDecoration(color: color, borderRadius: borderRadius);
  }
}

class AppText {
  // Display / headings you already used
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.neutral900,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.neutral900,
    height: 1.25,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.neutral900,
    height: 1.25,
  );

  // Body
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral700,
    height: 1.35,
  );

  static const TextStyle bodySemi = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral800,
    height: 1.35,
  );

  // Small / helper
  static const TextStyle small = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral600,
    height: 1.3,
  );

  static const caption = TextStyle(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral600,
  );

  static const overline = TextStyle(
    fontSize: 12,
    height: 1.2,
    letterSpacing: .2,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral600,
  );

  static TextStyle get button => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
    color: AppColors.neutral700, // tweak if you need light-on-dark
  );
}

// Optional: expose a ThemeData if you want consistent defaults everywhere.
// (Keeps your Material theme simple and aligned with the palette)
class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal500,
        primary: AppColors.teal500,
        secondary: AppColors.purple500,
        surface: AppColors.white,
      ),
      scaffoldBackgroundColor: AppColors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        elevation: 0,
        foregroundColor: AppColors.neutral900,
      ),
      cardColor: AppColors.white,
    );

    return base.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.neutral200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.neutral200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.teal500, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.neutral100,
        selectedColor: AppColors.teal100,
        labelStyle: AppText.small,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          side: const BorderSide(color: AppColors.neutral200),
        ),
      ),
    );
  }
}
