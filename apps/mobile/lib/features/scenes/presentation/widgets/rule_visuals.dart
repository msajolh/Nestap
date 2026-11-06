import 'package:flutter/material.dart';

/// Icon names stored on rules, with their glyphs.
const ruleIcons = <String, IconData>{
  'sunny': Icons.wb_sunny_rounded,
  'night': Icons.nightlight_round,
  'logout': Icons.logout_rounded,
  'home': Icons.home_rounded,
  'movie': Icons.movie_rounded,
  'bed': Icons.bed_rounded,
  'dining': Icons.restaurant_rounded,
  'party': Icons.celebration_rounded,
};

/// Card colors offered in the editor (Nestap palette).
const ruleColors = ['#00D3F3', '#43C6DB', '#96F7E4', '#A2F4FD', '#4A5565', '#101828', '#F0B100', '#FB2C36'];

IconData iconForRule(String? name) => ruleIcons[name] ?? Icons.auto_awesome_rounded;

Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// Navy or white, whichever reads better on [background].
Color foregroundOn(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF101828);
