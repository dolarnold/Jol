import 'package:flutter/material.dart';

@immutable
class JolTokens extends ThemeExtension<JolTokens> {
  const JolTokens({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.tabBar,
  });

  final Color background;
  final Color surface;
  final Color surface2;
  final Color text;
  final Color muted;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color tabBar;

  static const dark = JolTokens(
    background: Color(0xFF0B0B0B),
    surface: Color(0xFF161615),
    surface2: Color(0xFF22211F),
    text: Color(0xFFF1F0EC),
    muted: Color(0xFFA09C93),
    line: Color(0xFF2C2B28),
    accent: Color(0xFFB08D6C),
    onAccent: Color(0xFF0B0B0B),
    tabBar: Color(0xEB201F1D),
  );

  static const light = JolTokens(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF6F5F2),
    surface2: Color(0xFFECEBE6),
    text: Color(0xFF0B0B0B),
    muted: Color(0xFF68645C),
    line: Color(0xFFE6E4DE),
    accent: Color(0xFF7A5A40),
    onAccent: Color(0xFFF6F2EC),
    tabBar: Color(0xEB10100F),
  );

  static JolTokens of(BuildContext context) =>
      Theme.of(context).extension<JolTokens>()!;

  @override
  JolTokens copyWith({
    Color? background,
    Color? surface,
    Color? surface2,
    Color? text,
    Color? muted,
    Color? line,
    Color? accent,
    Color? onAccent,
    Color? tabBar,
  }) {
    return JolTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      tabBar: tabBar ?? this.tabBar,
    );
  }

  @override
  JolTokens lerp(ThemeExtension<JolTokens>? other, double t) {
    if (other is! JolTokens) return this;

    return JolTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      tabBar: Color.lerp(tabBar, other.tabBar, t)!,
    );
  }
}

abstract final class JolTheme {
  static final ThemeData dark = _build(JolTokens.dark, Brightness.dark);
  static final ThemeData light = _build(JolTokens.light, Brightness.light);

  static ThemeData _build(JolTokens tokens, Brightness brightness) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: tokens.accent,
          brightness: brightness,
        ).copyWith(
          primary: tokens.accent,
          onPrimary: tokens.onAccent,
          secondary: tokens.accent,
          onSecondary: tokens.onAccent,
          surface: tokens.surface,
          onSurface: tokens.text,
          outline: tokens.line,
          error: tokens.text,
          onError: tokens.background,
        );
    final displayStyle = TextStyle(
      fontFamily: 'ArchivoExpanded',
      color: tokens.text,
      height: 1.06,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      fontFamily: 'InstrumentSans',
      textTheme: TextTheme(
        displayLarge: displayStyle.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
        displayMedium: displayStyle.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: displayStyle.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: 28,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.98,
          height: 1.1,
          color: tokens.text,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: 16,
          height: 1.55,
          color: tokens.text,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: 14,
          height: 1.45,
          color: tokens.text,
        ),
        labelLarge: TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: tokens.text,
        ),
        labelSmall: TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.72,
          color: tokens.muted,
        ),
      ),
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.text,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: tokens.line),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        hintStyle: TextStyle(color: tokens.muted),
        labelStyle: TextStyle(color: tokens.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.text, width: 2),
        ),
      ),
    );
  }
}
