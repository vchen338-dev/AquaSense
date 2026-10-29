import 'package:flutter/material.dart';

import 'models.dart';

const kBg = Color(0xFF0A1220);
const kSurface = Color(0xFF111B2E);
const kSurface2 = Color(0xFF17243B);
const kText = Color(0xFFEAF1FB);
const kMuted = Color(0xFF8EA0BC);
const kAccent = Color(0xFF4DE1D0);
const kGood = Color(0xFF3DDC97);
const kWarn = Color(0xFFFFC857);
const kBad = Color(0xFFFF6B6B);

/// Opacity helper that works on every Flutter version.
Color alpha(Color c, double o) => c.withAlpha((o * 255).round().clamp(0, 255));

Color levelColor(Level l) {
  switch (l) {
    case Level.low:
      return kGood;
    case Level.mid:
      return kWarn;
    case Level.high:
      return kBad;
    case Level.fault:
      return kBad;
    case Level.warmup:
      return kMuted;
  }
}

String levelLabel(Level l) {
  switch (l) {
    case Level.low:
      return 'Safe';
    case Level.mid:
      return 'Rising';
    case Level.high:
      return 'Danger';
    case Level.fault:
      return 'Sensor error';
    case Level.warmup:
      return 'Warming up';
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: Brightness.dark,
  ).copyWith(primary: kAccent, surface: kSurface);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    canvasColor: kSurface,
    splashFactory: InkRipple.splashFactory,
    textTheme: Typography.whiteMountainView.apply(
      bodyColor: kText,
      displayColor: kText,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: alpha(kAccent, 0.18),
      height: 68,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: kMuted),
    ),
  );
}
