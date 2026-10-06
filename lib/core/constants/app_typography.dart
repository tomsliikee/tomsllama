import 'package:flutter/material.dart';

/// Three families, each with one job: Newsreader for long-form reading
/// (answers, headings), Inter for the interface (titles in lists, inputs,
/// short prose in dialogs), Geist Mono for labels, metadata and code.
class AppTypography {
  static const String serifFamily = 'Newsreader';
  static const String sansFamily = 'Inter';
  static const String monoFamily = 'GeistMono';

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

  /// 13 sans: list titles, short prose in the interface.
  static const TextStyle small = TextStyle(
    fontFamily: sansFamily,
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// 15 sans: text the user types, and the hint shown before they do.
  static const TextStyle input = TextStyle(
    fontFamily: sansFamily,
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 16.5 serif: answers and other long-form reading.
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
}
