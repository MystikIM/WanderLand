import 'package:flutter/material.dart';

// Sampled by eye from the MystikIM neon M logo: deep violet + hot pink.
const int kMystikViolet = 0xFF9B30FF;
const int kMystikMagenta = 0xFFFF29B4;

const List<String> kBundledFonts = [
  'Atkinson Hyperlegible', 'Space Mono', 'Pacifico', 'Indie Flower', 'Special Elite',
];

class ThemeConfig {
  const ThemeConfig({
    this.seedColor = kMystikViolet,
    this.accentColor = kMystikMagenta,
    this.mode = 'dark',
    this.fontFamily = 'Atkinson Hyperlegible',
    this.fontScale = 1.0,
    this.cornerRadius = 16,
  });

  final int seedColor;
  final int accentColor;
  final String mode;
  final String fontFamily;
  final double fontScale;
  final double cornerRadius;

  ThemeConfig copyWith({
    int? seedColor,
    int? accentColor,
    String? mode,
    String? fontFamily,
    double? fontScale,
    double? cornerRadius,
  }) =>
      ThemeConfig(
        seedColor: seedColor ?? this.seedColor,
        accentColor: accentColor ?? this.accentColor,
        mode: mode ?? this.mode,
        fontFamily: fontFamily ?? this.fontFamily,
        fontScale: fontScale ?? this.fontScale,
        cornerRadius: cornerRadius ?? this.cornerRadius,
      );

  Map<String, dynamic> toJson() => {
        'id': 'theme',
        'seedColor': seedColor,
        'accentColor': accentColor,
        'mode': mode,
        'fontFamily': fontFamily,
        'fontScale': fontScale,
        'cornerRadius': cornerRadius,
      };

  factory ThemeConfig.fromJson(Map<String, dynamic> j) => ThemeConfig(
        seedColor: j['seedColor'] as int? ?? kMystikViolet,
        accentColor: j['accentColor'] as int? ?? kMystikMagenta,
        mode: j['mode'] as String? ?? 'dark',
        fontFamily: j['fontFamily'] as String? ?? 'Atkinson Hyperlegible',
        fontScale: (j['fontScale'] as num?)?.toDouble() ?? 1.0,
        cornerRadius: (j['cornerRadius'] as num?)?.toDouble() ?? 16,
      );
}

ThemeMode themeModeOf(ThemeConfig c) => switch (c.mode) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

ThemeData buildTheme(ThemeConfig c, Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: Color(c.seedColor), brightness: b)
      .copyWith(secondary: Color(c.accentColor));
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(c.cornerRadius));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: c.fontFamily,
    cardTheme: CardThemeData(shape: shape),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: shape)),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(c.cornerRadius)),
    ),
  );
}
