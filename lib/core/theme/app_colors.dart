import 'package:flutter/material.dart';

/// Brand palette: deep indigo (the "night sky"), saffron and gold accents
/// (the "third eye" glow) on a warm ivory canvas.
class AppColors {
  static const ink = Color(0xFF1B1536);
  static const indigoDeep = Color(0xFF150E3A);
  static const indigo = Color(0xFF2E2373);
  static const violet = Color(0xFF5B49C9);
  static const lavender = Color(0xFFEFEBFB);

  static const saffron = Color(0xFFF08A24);

  /// Text and icons on a solid saffron fill (white would be only ~2.6:1).
  static const onSaffron = ink;

  /// Saffron / amber as *text* on light backgrounds.
  static const saffronText = Color(0xFF9A4A00);
  static const busyText = Color(0xFFA35A00);
  static const saffronSoft = Color(0xFFFFEBD3);
  static const gold = Color(0xFFE6B450);

  static const ivory = Color(0xFFFAF7F2);
  static const hairline = Color(0xFFECE6DC);
  static const muted = Color(0xFF6E6A80);

  // Deep enough for readable green text on white and ivory (WCAG AA).
  static const success = Color(0xFF17804F);
  static const busy = Color(0xFFD9822B);
  static const offline = Color(0xFF9B97AA);
  static const danger = Color(0xFFC8374A);

  /// A readable text colour for [c] when it is drawn on a light surface.
  static Color readableOnLight(Color c) {
    if (c == saffron) return saffronText;
    if (c == busy) return busyText;
    if (c == offline) return muted;
    return c;
  }

  /// Hero / splash background.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigoDeep, Color(0xFF241A63), Color(0xFF3A2A8F)],
  );

  /// Primary call-to-action fill.
  static const ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A2A8F), indigo],
  );
}
