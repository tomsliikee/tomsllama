import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A high-fidelity, performance-optimized frosted glass container (Glassmorphism)
/// with Gaussian backdrop blur, specular gradient sheen, and translucent refraction rim.
class FrostedGlass extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  const FrostedGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.blur = 24.0,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveRadius = borderRadius ?? BorderRadius.circular(16.0);

    final baseColor = backgroundColor ?? appColors.surface;

    // Specular Frosted Glass Gradient:
    // Rich milky/frosty diffuse scattering with a crisp top-left specular sheen
    final effectiveGradient = gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.40, 1.0],
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.12),
                  baseColor.withValues(alpha: 0.42),
                  baseColor.withValues(alpha: 0.22),
                ]
              : [
                  Colors.white.withValues(alpha: 0.68),
                  Color.alphaBlend(Colors.white.withValues(alpha: 0.35), baseColor)
                      .withValues(alpha: 0.46),
                  baseColor.withValues(alpha: 0.32),
                ],
        );

    // Crisp glass rim reflection
    final effectiveBorderColor = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.70));

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        gradient: effectiveGradient,
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
      ),
      child: child,
    );

    // ClipRRect with BackdropFilter in a Stack so the blur filters the backdrop,
    // and the translucent glass gradient renders over it with genuine transparency.
    Widget glass = ClipRRect(
      borderRadius: effectiveRadius,
      clipBehavior: clipBehavior,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: const SizedBox.expand(),
            ),
          ),
          content,
        ],
      ),
    );

    // Outer shadow: placed outside the ClipRRect so it is not clipped away
    if (boxShadow != null && boxShadow!.isNotEmpty) {
      glass = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: boxShadow,
        ),
        child: glass,
      );
    }

    if (margin != null) {
      glass = Padding(padding: margin!, child: glass);
    }

    return glass;
  }
}
