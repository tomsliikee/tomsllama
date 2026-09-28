import 'package:flutter/material.dart';

class AppTypography {
  static const String serifFamily = 'Newsreader';
  static const String sansFamily = 'Inter';
  static const String monoFamily = 'FiraCode';

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

  static const TextStyle headline = TextStyle(
    fontFamily: serifFamily,
    fontSize: 24.0,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle code = TextStyle(
    fontFamily: monoFamily,
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle telemetry = TextStyle(
    fontFamily: monoFamily,
    fontSize: 11.0,
    fontWeight: FontWeight.w400,
  );

  // Clean neutral sans for navigation, buttons and inputs (Claude style)
  static const TextStyle uiControl = TextStyle(
    fontFamily: sansFamily,
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
  );
}
