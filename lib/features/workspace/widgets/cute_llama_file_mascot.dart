import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CuteLlamaFileMascot extends StatefulWidget {
  final double size;

  const CuteLlamaFileMascot({
    super.key,
    this.size = 85.0,
  });

  @override
  State<CuteLlamaFileMascot> createState() => _CuteLlamaFileMascotState();
}

class _CuteLlamaFileMascotState extends State<CuteLlamaFileMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Timer _cycleTimer;

  // The file the llama holds changes type; the colour does not, it stays in the theme's accent.
  static const List<String> _fileTypes = ['.dart', '.pdf', '.md', '.json'];

  int _currentFileIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Initial trigger
    _controller.forward(from: 0.0);

    // Every 3 seconds, switch file and play playful animation
    _cycleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _currentFileIndex = (_currentFileIndex + 1) % _fileTypes.length;
      });
      _controller.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _cycleTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String currentExt = _fileTypes[_currentFileIndex];
    final Color fileColor = appColors.accent;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Tooltip(
          message: 'Workspace Context Manager ($currentExt)',
          waitDuration: const Duration(milliseconds: 400),
          child: SizedBox(
            width: widget.size * 1.15,
            height: widget.size,
            child: CustomPaint(
              painter: _LlamaMascotPainter(
                progress: t,
                accentColor: appColors.accent,
                fileColor: fileColor,
                fileExt: currentExt,
                isDark: isDark,
                surfaceColor: appColors.surface,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LlamaMascotPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final Color fileColor;
  final String fileExt;
  final bool isDark;
  final Color surfaceColor;

  _LlamaMascotPainter({
    required this.progress,
    required this.accentColor,
    required this.fileColor,
    required this.fileExt,
    required this.isDark,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double scale = w / 95.0;

    // Animation phases in the 900ms burst (which triggers every 3s)
    // 1. Ear twitch: 2 fast oscillations
    final double earWiggle = math.sin(progress * 4 * math.pi) * (1.0 - progress) * 3.5;
    // 2. Paper wiggle & bounce
    final double paperWiggle = math.sin(progress * 3 * math.pi) * (1.0 - progress) * 0.22;
    final double bounce = -math.sin(progress * math.pi) * 4.0;

    canvas.save();
    canvas.translate(0, bounce);

    final double originX = w * 0.12;
    final double originY = h * 0.18;

    final Paint outlinePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.20 : 0.14)
      ..style = PaintingStyle.fill;

    // Draw Llama head & neck
    final Path llama = Path()
      ..moveTo(originX + 8 * scale, originY + 48 * scale)
      ..lineTo(originX + 10 * scale, originY + 20 * scale)
      ..lineTo(originX + 7 * scale + earWiggle, originY + 3 * scale)   // Left ear
      ..lineTo(originX + 14 * scale, originY + 11 * scale)
      ..lineTo(originX + 20 * scale - earWiggle, originY + 4 * scale)  // Right ear
      ..lineTo(originX + 22 * scale, originY + 14 * scale)
      ..lineTo(originX + 37 * scale, originY + 18 * scale)            // Snout top
      ..lineTo(originX + 38 * scale, originY + 24 * scale)            // Nose
      ..lineTo(originX + 32 * scale, originY + 27 * scale)            // Chin
      ..lineTo(originX + 25 * scale, originY + 27 * scale)
      ..lineTo(originX + 27 * scale, originY + 38 * scale)            // Chest
      ..lineTo(originX + 28 * scale, originY + 48 * scale)
      ..close();

    canvas.drawPath(llama, fillPaint);
    canvas.drawPath(llama, outlinePaint);

    // Cute Eye (happy arch)
    final Paint eyePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..strokeCap = StrokeCap.round;

    final Rect eyeRect = Rect.fromCenter(
      center: Offset(originX + 23 * scale, originY + 20 * scale),
      width: 4.5 * scale,
      height: 3.2 * scale,
    );
    canvas.drawArc(eyeRect, math.pi, math.pi, false, eyePaint);

    // Cute Blushing Cheek
    final Paint blushPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(originX + 27 * scale, originY + 24 * scale),
      2.5 * scale,
      blushPaint,
    );

    // Arm holding the document
    final Path arm = Path()
      ..moveTo(originX + 27 * scale, originY + 38 * scale)
      ..quadraticBezierTo(
        originX + 36 * scale,
        originY + 40 * scale,
        originX + 44 * scale,
        originY + 37 * scale,
      );
    canvas.drawPath(arm, outlinePaint);

    // 3. Document held by Llama (with rotation wiggle)
    canvas.save();
    final Offset docCenter = Offset(originX + 54 * scale, originY + 34 * scale);
    canvas.translate(docCenter.dx, docCenter.dy);
    canvas.rotate(paperWiggle);

    const double docW = 28.0;
    const double docH = 34.0;
    final Rect docRect = Rect.fromCenter(
      center: Offset.zero,
      width: docW * scale,
      height: docH * scale,
    );
    final RRect roundedDoc = RRect.fromRectAndRadius(docRect, Radius.circular(4.0 * scale));

    // Document background fill
    final Paint docFill = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(roundedDoc, docFill);

    // Document border colored by file type
    final Paint docBorder = Paint()
      ..color = fileColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale;
    canvas.drawRRect(roundedDoc, docBorder);

    // Document folded corner top-right
    final double fold = 6.0 * scale;
    final Path foldPath = Path()
      ..moveTo(docRect.right - fold, docRect.top)
      ..lineTo(docRect.right, docRect.top + fold)
      ..lineTo(docRect.right - fold, docRect.top + fold)
      ..close();
    final Paint foldPaint = Paint()
      ..color = fileColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawPath(foldPath, foldPaint);

    // File Extension Label (e.g., .dart, .pdf, .md)
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: fileExt,
        style: TextStyle(
          color: fileColor,
          fontSize: 8.5 * scale,
          fontWeight: FontWeight.w700,
          fontFamily: 'GeistMono',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2 + 1.0 * scale),
    );

    // Hoof clasping document
    canvas.restore();
    final Paint hoofPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(originX + 44 * scale, originY + 37 * scale), 2.8 * scale, hoofPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LlamaMascotPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.fileExt != fileExt ||
        oldDelegate.accentColor != accentColor;
  }
}
