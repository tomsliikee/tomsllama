import 'package:flutter/material.dart';

/// Two families: Newsreader for anything that is read, Geist Mono for anything
/// that labels, measures or is code. Sizes come from the six-step scale below.
class AppTypography {
  static const String serifFamily = 'Newsreader';
  static const String monoFamily = 'GeistMono';

  // Still used by screens that have not been moved to the new scale yet.
  static const String sansFamily = 'Inter';

  // --- The scale ---

  /// 10.5 mono: section labels, set in tracked uppercase by the caller.
  static const TextStyle micro = TextStyle(
    fontFamily: monoFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.9,
    height: 1.2,
  );

  /// 12 mono: controls, chips, metadata.
  static const TextStyle label = TextStyle(
    fontFamily: monoFamily,
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.25,
  );

  /// 15 serif: list titles and secondary reading text.
  static const TextStyle small = TextStyle(
    fontFamily: serifFamily,
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// 16.5 serif: answers and anything typed by the user.
  static const TextStyle body = TextStyle(
    fontFamily: serifFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w400,
    height: 1.65,
  );

  static const TextStyle bodyItalic = TextStyle(
    fontFamily: serifFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 1.65,
  );

  /// 20 serif: headings.
  static const TextStyle title = TextStyle(
    fontFamily: serifFamily,
    fontSize: 20.0,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.1,
  );

  /// 30 serif: the one display size.
  static const TextStyle display = TextStyle(
    fontFamily: serifFamily,
    fontSize: 30.0,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -0.4,
  );

  static const TextStyle code = TextStyle(
    fontFamily: monoFamily,
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  /// Numbers that change in place (speed, tokens, timers) keep their width.
  static const TextStyle telemetry = TextStyle(
    fontFamily: monoFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // --- Pre-scale styles, kept for screens not yet restyled ---

  static const TextStyle headline = TextStyle(
    fontFamily: serifFamily,
    fontSize: 24.0,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle uiControl = TextStyle(
    fontFamily: sansFamily,
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
  );
}
