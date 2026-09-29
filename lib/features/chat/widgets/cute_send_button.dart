import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/localization_service.dart';

/// A circular send button that smoothly morphs into an organic cloud with
/// delightful side lobes ("Wolke mit Auswabungen") containing the cute animated
/// Llama mascot during message submission.
class CuteSendButton extends StatefulWidget {
  final bool isGenerating;
  final bool hasText;
  final VoidCallback? onTap;

  const CuteSendButton({
    super.key,
    required this.isGenerating,
    required this.hasText,
    required this.onTap,
  });

  @override
  State<CuteSendButton> createState() => CuteSendButtonState();
}

class CuteSendButtonState extends State<CuteSendButton> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  int _animIndex = 0;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Triggers the cute cloud morph and mascot animation.
  void triggerCuteAnimation() {
    if (!mounted) return;
    setState(() {
      _animIndex = (_animIndex + 1) % 3;
    });
    _animController.forward(from: 0.0);
  }

  double _calculateMorphProgress(double t) {
    if (t < 0.18) {
      final subT = (t / 0.18).clamp(0.0, 1.0);
      return Curves.easeOutBack.transform(subT).clamp(0.0, 1.05);
    } else if (t < 0.80) {
      return 1.0;
    } else {
      final subT = ((t - 0.80) / 0.20).clamp(0.0, 1.0);
      return (1.0 - Curves.easeInOutCubic.transform(subT)).clamp(0.0, 1.0);
    }
  }

  double _calculateCuteProgress(double t) {
    if (t < 0.18) return 0.0;
    if (t > 0.80) return 1.0;
    return ((t - 0.18) / 0.62).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canInteract = widget.isGenerating || widget.hasText;

    final bgColor = widget.isGenerating || widget.hasText
        ? appColors.accent
        : (_isHovered ? appColors.hover : (isDark ? appColors.surface : appColors.background));

    final iconColor = widget.isGenerating || widget.hasText
        ? Colors.white
        : appColors.textSecondary.withValues(alpha: 0.45);

    final borderColor = widget.isGenerating || widget.hasText
        ? appColors.accent
        : (_isHovered ? appColors.border : appColors.borderSubtle);

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final double animValue = _animController.value;
        final double morphProgress = animValue > 0.0 ? _calculateMorphProgress(animValue) : 0.0;
        final double cuteProgress = animValue > 0.0 ? _calculateCuteProgress(animValue) : 0.0;
        final bool isMorphing = morphProgress > 0.01;

        // Base circular dimensions
        const double circleDiameter = 34.0;
        // Expanded cloud dimensions
        final double cloudWidth = circleDiameter + (88.0 - circleDiameter) * morphProgress;
        final double cloudHeight = circleDiameter + (48.0 - circleDiameter) * morphProgress;

        return Tooltip(
          message: widget.isGenerating ? I18n.stop : I18n.send,
          waitDuration: const Duration(milliseconds: 600),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: () {
              if (widget.onTap != null) {
                if (!widget.isGenerating && widget.hasText) {
                  triggerCuteAnimation();
                }
                widget.onTap!();
              }
            },
            child: AnimatedScale(
              scale: _isPressed ? 0.93 : (_isHovered && canInteract && !isMorphing ? 1.05 : 1.0),
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutBack,
              child: SizedBox(
                width: isMorphing ? cloudWidth : circleDiameter,
                height: isMorphing ? cloudHeight : circleDiameter,
                child: CustomPaint(
                  painter: _CloudMorphPainter(
                    morphProgress: morphProgress,
                    cuteProgress: cuteProgress,
                    animType: _animIndex,
                    isDark: isDark,
                    accentColor: appColors.accent,
                    circleBgColor: bgColor,
                    circleBorderColor: borderColor,
                    cloudBgColor: isDark
                        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.06), appColors.surface)
                        : Colors.white,
                    llamaColor: isDark ? Colors.white : const Color(0xFF181816),
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: (1.0 - (morphProgress * 2.5)).clamp(0.0, 1.0),
                      child: Icon(
                        widget.isGenerating
                            ? Icons.stop_rounded
                            : Icons.arrow_upward_rounded,
                        size: 17.0,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      },
    );
  }
}

/// Custom painter that seamlessly morphs from a circle into an organic puffy
/// cloud with bulging side lobes and renders the animated Llama in the center.
class _CloudMorphPainter extends CustomPainter {
  final double morphProgress;
  final double cuteProgress;
  final int animType;
  final bool isDark;
  final Color accentColor;
  final Color circleBgColor;
  final Color circleBorderColor;
  final Color cloudBgColor;
  final Color llamaColor;

  _CloudMorphPainter({
    required this.morphProgress,
    required this.cuteProgress,
    required this.animType,
    required this.isDark,
    required this.accentColor,
    required this.circleBgColor,
    required this.circleBorderColor,
    required this.cloudBgColor,
    required this.llamaColor,
  });

  Path _createMorphPath(Size size, double p) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final circleRadius = math.min(size.width, size.height) / 2;

    if (p <= 0.01) {
      return Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: circleRadius));
    }

    // Base body: softly rounded pill
    final baseWidth = math.min(size.width * 0.72, 60.0 * p);
    final baseHeight = math.min(size.height * 0.58, 28.0 * p);
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy + 3.0 * p),
        width: math.max(circleRadius * 2, baseWidth),
        height: math.max(circleRadius * 2, baseHeight),
      ),
      Radius.circular(circleRadius),
    );
    Path cloudPath = Path()..addRRect(baseRect);

    // Left bulge lobe ("Auswabungen auf der Seite")
    final leftLobe = Path()..addOval(
      Rect.fromCircle(
        center: Offset(cx - 25.0 * p, cy + 2.0 * p),
        radius: 13.5 * p,
      ),
    );
    cloudPath = Path.combine(PathOperation.union, cloudPath, leftLobe);

    // Left-upper puffy lobe
    final leftTopLobe = Path()..addOval(
      Rect.fromCircle(
        center: Offset(cx - 15.0 * p, cy - 8.0 * p),
        radius: 14.5 * p,
      ),
    );
    cloudPath = Path.combine(PathOperation.union, cloudPath, leftTopLobe);

    // Center high dome
    final centerDome = Path()..addOval(
      Rect.fromCircle(
        center: Offset(cx, cy - 11.5 * p),
        radius: 16.5 * p,
      ),
    );
    cloudPath = Path.combine(PathOperation.union, cloudPath, centerDome);

    // Right-upper puffy lobe
    final rightTopLobe = Path()..addOval(
      Rect.fromCircle(
        center: Offset(cx + 15.0 * p, cy - 8.0 * p),
        radius: 14.5 * p,
      ),
    );
    cloudPath = Path.combine(PathOperation.union, cloudPath, rightTopLobe);

    // Right bulge lobe ("Auswabungen auf der Seite")
    final rightLobe = Path()..addOval(
      Rect.fromCircle(
        center: Offset(cx + 25.0 * p, cy + 2.0 * p),
        radius: 13.5 * p,
      ),
    );
    cloudPath = Path.combine(PathOperation.union, cloudPath, rightLobe);

    return cloudPath;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _createMorphPath(size, morphProgress);

    // Drop shadow
    if (morphProgress > 0.05) {
      final shadowPaint = Paint()
        ..color = accentColor.withValues(alpha: isDark ? 0.28 : 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);
    }

    // Background fill (interpolates from circle color to cloud color)
    final fillPaint = Paint()
      ..color = Color.lerp(circleBgColor, cloudBgColor, morphProgress.clamp(0.0, 1.0))!
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border stroke (accent hairline)
    final borderPaint = Paint()
      ..color = Color.lerp(circleBorderColor, accentColor, morphProgress.clamp(0.0, 1.0))!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + (0.3 * morphProgress);
    canvas.drawPath(path, borderPaint);

    // Render Cute Llama Mascot when cloud is bloomed
    if (morphProgress >= 0.5) {
      final double mascotAlpha = ((morphProgress - 0.5) / 0.5).clamp(0.0, 1.0);
      canvas.save();
      final center = Offset(size.width / 2, size.height / 2 + 1.0);

      double yOffset = 0.0;
      double rotation = 0.0;
      bool isWinking = false;
      double earWiggle = 0.0;

      if (animType == 0) {
        // 0: Ear Wiggle & Sparkles
        rotation = math.sin(cuteProgress * math.pi * 4) * 0.08;
        earWiggle = math.sin(cuteProgress * math.pi * 8) * 0.25;
      } else if (animType == 1) {
        // 1: Bouncy Hop & Floating Heart
        yOffset = -((math.sin(cuteProgress * math.pi * 4)).abs()) * 3.5;
        rotation = math.sin(cuteProgress * math.pi * 2) * 0.04;
      } else {
        // 2: Eager Nod & Wink
        yOffset = math.sin(cuteProgress * math.pi * 6) * 2.0;
        isWinking = cuteProgress >= 0.25 && cuteProgress <= 0.70;
      }

      canvas.translate(center.dx, center.dy + yOffset);
      canvas.rotate(rotation);

      _drawLlama(canvas, earWiggle, isWinking, mascotAlpha);
      canvas.restore();

      // Floating joyful effects
      if (animType == 0) {
        _drawSparkles(canvas, center, mascotAlpha);
      } else if (animType == 1) {
        _drawHeart(canvas, center, mascotAlpha);
      } else {
        _drawNodStars(canvas, center, mascotAlpha);
      }
    }
  }

  void _drawLlama(Canvas canvas, double earWiggle, bool isWinking, double alpha) {
    const double scale = 0.78;

    final Path bodyPath = Path()
      ..moveTo(-5.0 * scale, 9.0 * scale)
      ..lineTo(-4.5 * scale, 0.0 * scale)
      // Left ear (with gentle wiggle)
      ..lineTo((-5.5 + earWiggle * 2.2) * scale, -9.5 * scale)
      ..lineTo(-2.0 * scale, -4.5 * scale)
      // Right ear (with opposite gentle wiggle)
      ..lineTo((0.5 - earWiggle * 2.2) * scale, -8.5 * scale)
      ..lineTo(2.0 * scale, -3.0 * scale)
      // Snout
      ..lineTo(8.5 * scale, -1.0 * scale)
      ..lineTo(9.0 * scale, 2.0 * scale)
      ..lineTo(7.0 * scale, 3.5 * scale)
      ..lineTo(3.5 * scale, 3.5 * scale)
      ..lineTo(4.0 * scale, 9.0 * scale)
      ..close();

    // Body fill
    final fillPaint = Paint()
      ..color = llamaColor.withValues(alpha: (isDark ? 0.22 : 0.12) * alpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, fillPaint);

    // Body outline
    final outlinePaint = Paint()
      ..color = llamaColor.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(bodyPath, outlinePaint);

    // Blush cheek
    final blushPaint = Paint()
      ..color = Colors.pinkAccent.shade100.withValues(alpha: 0.65 * alpha)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(3.5, 1.5), 1.25, blushPaint);

    // Eye or wink
    if (isWinking) {
      final winkPaint = Paint()
        ..color = llamaColor.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        const Offset(0.4, -0.4),
        const Offset(2.4, 0.4),
        winkPaint,
      );
    } else {
      final eyePaint = Paint()
        ..color = llamaColor.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(1.5, -0.4), 0.8, eyePaint);
    }
  }

  void _drawSparkles(Canvas canvas, Offset center, double alpha) {
    final double sparkleScale = (math.sin(cuteProgress * math.pi)).clamp(0.0, 1.0) * alpha;
    if (sparkleScale <= 0.05) return;

    final Offset s1 = Offset(center.dx - 22.0, center.dy - 6.0);
    _draw4PointStar(canvas, s1, 3.4 * sparkleScale, isDark ? Colors.amberAccent : Colors.amber.shade700);

    final Offset s2 = Offset(center.dx + 20.0, center.dy - 8.0);
    _draw4PointStar(canvas, s2, 3.0 * sparkleScale, accentColor);
  }

  void _drawHeart(Canvas canvas, Offset center, double alpha) {
    final double heartProgress = (cuteProgress * 1.3).clamp(0.0, 1.0);
    if (heartProgress <= 0.05 || heartProgress >= 0.95) return;

    final double hx = center.dx + 18.0;
    final double hy = center.dy - 2.0 - heartProgress * 14.0;
    final double hs = (math.sin(heartProgress * math.pi)).clamp(0.0, 1.0) * 2.0 * alpha;

    final Path heartPath = Path()
      ..moveTo(hx, hy + hs * 0.8)
      ..cubicTo(hx - hs * 1.8, hy - hs * 1.5, hx - hs * 2.5, hy + hs * 0.8, hx, hy + hs * 2.5)
      ..cubicTo(hx + hs * 2.5, hy + hs * 0.8, hx + hs * 1.8, hy - hs * 1.5, hx, hy + hs * 0.8)
      ..close();

    final Paint heartPaint = Paint()
      ..color = Colors.pinkAccent.shade100.withValues(alpha: (1.0 - heartProgress * 0.7) * alpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(heartPath, heartPaint);
  }

  void _drawNodStars(Canvas canvas, Offset center, double alpha) {
    final double starScale = (math.sin(cuteProgress * math.pi)).clamp(0.0, 1.0) * alpha;
    if (starScale <= 0.05) return;

    final Offset p1 = Offset(center.dx + 21.0, center.dy - 5.0);
    _draw4PointStar(canvas, p1, 2.8 * starScale, isDark ? Colors.amberAccent : Colors.amber.shade700);

    final Offset p2 = Offset(center.dx - 20.0, center.dy - 4.0);
    _draw4PointStar(canvas, p2, 2.2 * starScale, accentColor);
  }

  void _draw4PointStar(Canvas canvas, Offset pos, double size, Color color) {
    final Path path = Path()
      ..moveTo(pos.dx, pos.dy - size)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx + size, pos.dy)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + size)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx - size, pos.dy)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - size)
      ..close();

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CloudMorphPainter oldDelegate) {
    return oldDelegate.morphProgress != morphProgress ||
        oldDelegate.cuteProgress != cuteProgress ||
        oldDelegate.animType != animType ||
        oldDelegate.circleBgColor != circleBgColor ||
        oldDelegate.cloudBgColor != cloudBgColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.llamaColor != llamaColor ||
        oldDelegate.isDark != isDark;
  }
}
