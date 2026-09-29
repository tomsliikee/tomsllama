import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TomsllamaLogoPainter extends CustomPainter {
  final Color accentColor;
  final double idleProgress;
  final int idleAnimType;

  TomsllamaLogoPainter({
    required this.accentColor,
    this.idleProgress = 0.0,
    this.idleAnimType = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double scaleX = w / 24.0;
    final double scaleY = h / 24.0;

    final double t = idleProgress;
    double rotation = 0.0;
    double yOffset = 0.0;
    double earTwitch = 0.0;
    bool isWinking = false;
    bool isSquinting = false;

    if (t > 0.0) {
      if (idleAnimType == 0) {
        // Type 0: Curious head tilt with ear twitch and cute winking blush
        rotation = math.sin(t * math.pi) * 0.18;
        earTwitch = math.sin(t * math.pi * 6) * 2.4 * scaleX;
        isWinking = t >= 0.20 && t <= 0.80;
      } else {
        // Type 1: Gentle curious bounce with ear flutter and happy squint
        yOffset = -((math.sin(t * math.pi * 2)).abs()) * 3.2 * scaleY;
        earTwitch = math.sin(t * math.pi * 5) * 1.8 * scaleX;
        isSquinting = t >= 0.18 && t <= 0.82;
      }
    }

    final Offset center = Offset(w / 2, h / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy + yOffset);
    if (rotation != 0.0) {
      canvas.rotate(rotation);
    }
    canvas.translate(-center.dx, -center.dy);

    final Paint outlinePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final Path path = Path()
      ..moveTo(8.0 * scaleX, 21.0 * scaleY)
      ..lineTo(8.5 * scaleX, 10.5 * scaleY)
      ..lineTo((7.5 * scaleX) + earTwitch, 4.0 * scaleY) // Left ear with gentle twitch
      ..lineTo(10.0 * scaleX, 7.5 * scaleY)             // Between ears
      ..lineTo((12.0 * scaleX) - earTwitch, 4.5 * scaleY) // Right ear with counter twitch
      ..lineTo(13.0 * scaleX, 8.5 * scaleY)             // Forehead
      ..lineTo(18.3 * scaleX, 10.0 * scaleY)            // Snout top
      ..lineTo(18.7 * scaleX, 12.5 * scaleY)            // Snout tip
      ..lineTo(17.0 * scaleX, 13.5 * scaleY)            // Chin
      ..lineTo(14.0 * scaleX, 13.5 * scaleY)            // Jaw
      ..lineTo(14.5 * scaleX, 21.0 * scaleY)            // Chest
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, outlinePaint);

    // Eye: round dot, cute wink line, or happy squint arc
    if (isWinking) {
      final Paint winkPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 * scaleX
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(11.6 * scaleX, 11.2 * scaleY),
        Offset(13.4 * scaleX, 10.6 * scaleY),
        winkPaint,
      );
    } else if (isSquinting) {
      final Paint squintPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 * scaleX
        ..strokeCap = StrokeCap.round;
      final Rect eyeRect = Rect.fromCenter(
        center: Offset(12.5 * scaleX, 11.2 * scaleY),
        width: 2.4 * scaleX,
        height: 1.8 * scaleY,
      );
      canvas.drawArc(eyeRect, math.pi, math.pi, false, squintPaint);
    } else {
      final Paint eyePaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(12.5 * scaleX, 11.0 * scaleY), 0.9 * scaleX, eyePaint);
    }

    // Inner ear detail
    final Paint detailPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset((8.5 * scaleX) + earTwitch * 0.5, 6.0 * scaleY),
      Offset(9.5 * scaleX, 8.0 * scaleY),
      detailPaint,
    );

    // Cute blush cheek when animating
    if (t > 0.0) {
      final double blushAlpha = (math.sin(t * math.pi)).clamp(0.0, 1.0) * 0.65;
      if (blushAlpha > 0.05) {
        final Paint blushPaint = Paint()
          ..color = Colors.pinkAccent.shade100.withValues(alpha: blushAlpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(14.0 * scaleX, 12.8 * scaleY),
          1.3 * scaleX,
          blushPaint,
        );
      }
    }

    canvas.restore();

    // Floating cute particles in world space
    if (t > 0.0) {
      final double particleAlpha = (math.sin(t * math.pi)).clamp(0.0, 1.0);
      if (particleAlpha > 0.05) {
        if (idleAnimType == 0) {
          // Tiny sparkle near ear
          final Offset sparklePos = Offset(w * 0.32, h * 0.16 - t * 3.0 * scaleY);
          _draw4PointStar(canvas, sparklePos, 2.2 * scaleX * particleAlpha, accentColor.withValues(alpha: particleAlpha * 0.8));
        } else {
          // Tiny star near snout
          final Offset starPos = Offset(w * 0.82, h * 0.36 - t * 4.0 * scaleY);
          _draw4PointStar(canvas, starPos, 2.0 * scaleX * particleAlpha, Colors.amber.withValues(alpha: particleAlpha * 0.85));
        }
      }
    }
  }

  void _draw4PointStar(Canvas canvas, Offset pos, double starSize, Color color) {
    if (starSize <= 0.2) return;
    final Path path = Path()
      ..moveTo(pos.dx, pos.dy - starSize)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx + starSize, pos.dy)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + starSize)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx - starSize, pos.dy)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - starSize)
      ..close();

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TomsllamaLogoPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.idleProgress != idleProgress ||
        oldDelegate.idleAnimType != idleAnimType;
  }
}

typedef GemlamaLogoPainter = TomsllamaLogoPainter;

class TomsllamaLogo extends StatefulWidget {
  final double size;
  final bool animate;
  final bool enableIdleAnimation;

  const TomsllamaLogo({
    super.key,
    this.size = 20.0,
    this.animate = true,
    this.enableIdleAnimation = false,
  });

  @override
  State<TomsllamaLogo> createState() => _TomsllamaLogoState();
}

class _TomsllamaLogoState extends State<TomsllamaLogo> with SingleTickerProviderStateMixin {
  AnimationController? _idleController;
  Timer? _idleTimer;
  int _idleAnimIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.enableIdleAnimation) {
      _initIdleAnimation();
    }
  }

  void _initIdleAnimation() {
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    // Runs every 10 seconds unconditionally (even when window is unfocused)
    _idleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _idleAnimIndex = (_idleAnimIndex + 1) % 2;
      });
      _idleController?.forward(from: 0.0);
    });
  }

  @override
  void didUpdateWidget(TomsllamaLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableIdleAnimation != oldWidget.enableIdleAnimation) {
      if (widget.enableIdleAnimation) {
        _initIdleAnimation();
      } else {
        _idleTimer?.cancel();
        _idleTimer = null;
        _idleController?.dispose();
        _idleController = null;
      }
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _idleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    if (widget.enableIdleAnimation && _idleController != null) {
      return AnimatedBuilder(
        animation: _idleController!,
        builder: (context, _) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: TomsllamaLogoPainter(
                accentColor: appColors.accent,
                idleProgress: _idleController?.value ?? 0.0,
                idleAnimType: _idleAnimIndex,
              ),
            ),
          );
        },
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: TomsllamaLogoPainter(
          accentColor: appColors.accent,
          idleProgress: 0.0,
          idleAnimType: 0,
        ),
      ),
    );
  }
}

typedef GemlamaLogo = TomsllamaLogo;
