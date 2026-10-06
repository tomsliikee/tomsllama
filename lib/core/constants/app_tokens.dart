import 'package:flutter/material.dart';

/// Corner radii. A shape nested inside another uses the next step down, so
/// inner corners follow outer ones instead of fighting them.
class AppRadii {
  static const double panel = 18.0;
  static const double card = 12.0;
  static const double control = 8.0;
  static const double pill = 999.0;
}

class AppSpace {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Three speeds and two curves for the whole app. Hover feedback is immediate,
/// state changes are quick, layout changes take long enough to follow.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);

  static const Curve standard = Curves.easeOutCubic;

  /// Slight overshoot for things that respond to a press.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1.0);
}

class AppElevation {
  /// The only shadow in the app, for surfaces that float above the page
  /// (composer, popovers, a dragged item). Everything else separates by fill.
  static List<BoxShadow> floating(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.06),
        blurRadius: isDark ? 18.0 : 14.0,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
        blurRadius: 3.0,
        offset: const Offset(0, 1),
      ),
    ];
  }
}
