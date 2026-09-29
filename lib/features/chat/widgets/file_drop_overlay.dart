import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';

class FileDropOverlay extends StatefulWidget {
  const FileDropOverlay({super.key});

  @override
  State<FileDropOverlay> createState() => _FileDropOverlayState();
}

class _FileDropOverlayState extends State<FileDropOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final pulseAlpha = 0.5 + 0.5 * math.sin(t * 2 * math.pi);

        return Stack(
          children: [
            // Darkened background with gentle backdrop blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                child: Container(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.68)
                      : Colors.black.withValues(alpha: 0.42),
                ),
              ),
            ),

            // Drop zone boundary with subtle accent glow
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: appColors.accent.withValues(alpha: 0.45 + pulseAlpha * 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: appColors.accent.withValues(alpha: 0.12 * pulseAlpha),
                        blurRadius: 16.0,
                        spreadRadius: 2.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Central Animated Character & Hint Text
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(190, 190),
                    painter: _CuteLlamaHoldingDocPainter(
                      progress: t,
                      accentColor: appColors.accent,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    I18n.dropFilesToAttach,
                    style: AppTypography.headline.copyWith(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      shadows: [
                        const Shadow(
                          color: Colors.black54,
                          blurRadius: 6.0,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0x33FFFFFF)
                          : const Color(0x44FFFFFF),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      I18n.willAttachToConversation,
                      style: AppTypography.uiControl.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CuteLlamaHoldingDocPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final bool isDark;

  _CuteLlamaHoldingDocPainter({
    required this.progress,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double t = progress;

    // Bobbing hover animation
    final double bobOffset = math.sin(t * 2 * math.pi) * 6.0;

    // Ear twitches
    final double earTwitchLeft = math.sin(t * 4 * math.pi) * 2.8;
    final double earTwitchRight = -math.sin(t * 4 * math.pi) * 2.2;

    // Document wiggle angle around the hoof pivot
    // Fast playful wobble: ~2.5 full oscillations per cycle
    final double docWiggleAngle = math.sin(t * 5 * math.pi) * 0.24;

    canvas.save();
    canvas.translate(0, bobOffset);

    // Coordinate mapping: center the llama around (w * 0.38, h * 0.50)
    final double scale = w / 160.0;
    final double originX = w * 0.26;
    final double originY = h * 0.26;

    // 1. Draw Llama Body & Head
    final Paint outlinePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.25 : 0.20)
      ..style = PaintingStyle.fill;

    // Head, ears, snout, neck profile
    final Path llamaPath = Path()
      ..moveTo(originX + 10 * scale, originY + 70 * scale) // Back of neck
      ..lineTo(originX + 12 * scale, originY + 28 * scale)
      ..lineTo(originX + (8 * scale) + earTwitchLeft, originY + 4 * scale) // Left ear
      ..lineTo(originX + 17 * scale, originY + 16 * scale)                // Between ears
      ..lineTo(originX + (24 * scale) + earTwitchRight, originY + 6 * scale) // Right ear
      ..lineTo(originX + 27 * scale, originY + 20 * scale)                // Forehead
      ..lineTo(originX + 46 * scale, originY + 25 * scale)                // Snout top
      ..lineTo(originX + 47 * scale, originY + 33 * scale)                // Snout tip
      ..lineTo(originX + 40 * scale, originY + 36 * scale)                // Chin
      ..lineTo(originX + 31 * scale, originY + 36 * scale)                // Jaw
      ..lineTo(originX + 34 * scale, originY + 54 * scale)                // Chest
      // Extend front chest down
      ..lineTo(originX + 36 * scale, originY + 70 * scale)
      ..close();

    canvas.drawPath(llamaPath, fillPaint);
    canvas.drawPath(llamaPath, outlinePaint);

    // Inner ear line
    final Paint detailPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(originX + 12 * scale + earTwitchLeft * 0.4, originY + 12 * scale),
      Offset(originX + 15 * scale, originY + 20 * scale),
      detailPaint,
    );

    // Cute Eye: Happy squinting crescent (looking happily down at the paper)
    final Paint eyePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale
      ..strokeCap = StrokeCap.round;
    final Rect eyeRect = Rect.fromCenter(
      center: Offset(originX + 29 * scale, originY + 27 * scale),
      width: 5.5 * scale,
      height: 4.0 * scale,
    );
    canvas.drawArc(eyeRect, math.pi, math.pi, false, eyePaint);

    // Cute Blushing Cheek
    final double blushAlpha = (0.5 + 0.4 * math.sin(t * 2 * math.pi)).clamp(0.0, 1.0);
    final Paint blushPaint = Paint()
      ..color = Colors.pinkAccent.shade100.withValues(alpha: blushAlpha * 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(originX + 33 * scale, originY + 33 * scale),
      3.2 * scale,
      blushPaint,
    );

    // 2. Cute Arm extending forward to hold the document
    final Path armPath = Path()
      ..moveTo(originX + 33 * scale, originY + 54 * scale)
      ..quadraticBezierTo(
        originX + 44 * scale,
        originY + 58 * scale,
        originX + 54 * scale,
        originY + 53 * scale,
      );
    final Paint armPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(armPath, armPaint);

    // 3. Document Wiggling in the Hoof
    // Pivot is at the tip of the arm / hoof
    final Offset hoofPivot = Offset(originX + 54 * scale, originY + 53 * scale);

    canvas.save();
    canvas.translate(hoofPivot.dx, hoofPivot.dy);
    canvas.rotate(docWiggleAngle);

    // Document Dimensions
    final double docW = 32.0 * scale;
    final double docH = 42.0 * scale;
    // Position document so hoof holds its lower-left corner
    final Rect docRect = Rect.fromLTWH(-4 * scale, -docH + 10 * scale, docW, docH);

    // Shadow behind the document
    final Path docShadowPath = _createDogEaredDocPath(docRect, 8.0 * scale);
    canvas.drawPath(
      docShadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // Document Background (Crisp pure white with soft glow)
    final Paint docBgPaint = Paint()
      ..color = const Color(0xFFFAF9F6)
      ..style = PaintingStyle.fill;
    canvas.drawPath(docShadowPath, docBgPaint);

    // Document Outline
    final Paint docBorderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(docShadowPath, docBorderPaint);

    // Folded dog-ear corner detail
    final double foldSize = 8.0 * scale;
    final Path foldPath = Path()
      ..moveTo(docRect.right - foldSize, docRect.top)
      ..lineTo(docRect.right - foldSize, docRect.top + foldSize)
      ..lineTo(docRect.right, docRect.top + foldSize)
      ..close();
    canvas.drawPath(
      foldPath,
      Paint()
        ..color = accentColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(foldPath, docBorderPaint);

    // Document Content Lines (simulated code / text lines)
    final Paint linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round;

    final double lineLeft = docRect.left + 6.0 * scale;
    // Line 1 (shorter because of fold)
    canvas.drawLine(
      Offset(lineLeft, docRect.top + 8.0 * scale),
      Offset(docRect.right - foldSize - 3 * scale, docRect.top + 8.0 * scale),
      linePaint,
    );
    // Line 2
    canvas.drawLine(
      Offset(lineLeft, docRect.top + 16.0 * scale),
      Offset(docRect.right - 6.0 * scale, docRect.top + 16.0 * scale),
      linePaint,
    );
    // Line 3
    canvas.drawLine(
      Offset(lineLeft, docRect.top + 24.0 * scale),
      Offset(docRect.left + 16.0 * scale, docRect.top + 24.0 * scale),
      linePaint,
    );
    // Line 4
    canvas.drawLine(
      Offset(lineLeft, docRect.top + 32.0 * scale),
      Offset(docRect.right - 10.0 * scale, docRect.top + 32.0 * scale),
      linePaint,
    );

    // Document mini code tag badge '{ }'
    final Paint tagPaint = Paint()
      ..color = Colors.amber.shade700
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(docRect.left + 7 * scale, docRect.top + docH - 6 * scale), 2.2 * scale, tagPaint);

    canvas.restore(); // Restore document transform

    // 4. Little rounded hoof clamping the document in front
    final Paint hoofPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(hoofPivot, 3.4 * scale, hoofPaint);
    canvas.drawCircle(
      hoofPivot,
      3.4 * scale,
      Paint()
        ..color = isDark ? Colors.black45 : Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale,
    );

    canvas.restore(); // Restore bobOffset

    // 5. Floating Magic Sparkles / 4-Point Stars
    _drawSparkles(canvas, size, t, scale);
  }

  Path _createDogEaredDocPath(Rect rect, double foldSize) {
    return Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right - foldSize, rect.top)
      ..lineTo(rect.right, rect.top + foldSize)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  void _drawSparkles(Canvas canvas, Size size, double t, double scale) {
    final double w = size.width;
    final double h = size.height;

    // Star 1: Golden star near waving document
    final double s1Alpha = (math.sin((t * 2 * math.pi) + 0.5)).clamp(0.0, 1.0);
    if (s1Alpha > 0.05) {
      final Offset pos1 = Offset(w * 0.76, h * 0.30 - t * 8.0);
      _draw4PointStar(
        canvas,
        pos1,
        3.6 * scale * s1Alpha,
        Colors.amberAccent.withValues(alpha: s1Alpha),
      );
    }

    // Star 2: Accent star above ear
    final double s2Alpha = (math.sin((t * 2 * math.pi) + 2.5)).clamp(0.0, 1.0);
    if (s2Alpha > 0.05) {
      final Offset pos2 = Offset(w * 0.28, h * 0.22 - t * 6.0);
      _draw4PointStar(
        canvas,
        pos2,
        3.0 * scale * s2Alpha,
        accentColor.withValues(alpha: s2Alpha),
      );
    }

    // Star 3: Soft white/pink star near chest/document
    final double s3Alpha = (math.sin((t * 2 * math.pi) + 4.2)).clamp(0.0, 1.0);
    if (s3Alpha > 0.05) {
      final Offset pos3 = Offset(w * 0.82, h * 0.65 - t * 5.0);
      _draw4PointStar(
        canvas,
        pos3,
        2.5 * scale * s3Alpha,
        Colors.white.withValues(alpha: s3Alpha * 0.85),
      );
    }
  }

  void _draw4PointStar(Canvas canvas, Offset pos, double starSize, Color color) {
    if (starSize <= 0.3) return;
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
  bool shouldRepaint(covariant _CuteLlamaHoldingDocPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}
