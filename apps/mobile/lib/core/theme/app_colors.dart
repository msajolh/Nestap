import 'package:material_ui/material_ui.dart';

/// Nestap palette, taken from the logo and nestap.net.
abstract final class AppColors {
  // Brand
  static const brand = Color(0xFF43C6DB); // logo cyan
  static const cyan200 = Color(0xFFA2F4FD);
  static const cyan400 = Color(0xFF00D3F3); // primary call-to-action fill
  static const cyan500 = Color(0xFF00B8DB);
  static const cyan700 = Color(0xFF007595); // accessible cyan on white
  static const teal200 = Color(0xFF96F7E4);

  // Neutrals
  static const ink = Color(0xFF030712); // darkest section / dark scaffold
  static const navy = Color(0xFF101828); // headings, dark surfaces, CTA text
  static const navy800 = Color(0xFF1E2939);
  static const navy700 = Color(0xFF364153);
  static const slate = Color(0xFF4A5565); // secondary text
  static const gray400 = Color(0xFF99A1AF);
  static const gray300 = Color(0xFFD1D5DC); // borders, text on dark
  static const gray200 = Color(0xFFE5E7EB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray50 = Color(0xFFF9FAFB);

  // Status
  static const success = Color(0xFF00C950);
  static const warning = Color(0xFFF0B100);
  static const error = Color(0xFFFB2C36);

  /// Hero panels (sign-in, home summary), like the site's dark sections.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, ink],
  );

  /// Glow behind devices that are on.
  static const activeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan400, brand],
  );
}
