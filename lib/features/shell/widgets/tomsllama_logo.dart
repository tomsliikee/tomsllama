import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TomsllamaLogoPainter extends CustomPainter {
  final Color accentColor;

  TomsllamaLogoPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double scaleX = w / 24.0;
    final double scaleY = h / 24.0;

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
      ..lineTo(7.5 * scaleX, 4.0 * scaleY)   // Left ear
      ..lineTo(10.0 * scaleX, 7.5 * scaleY)  // Between ears
      ..lineTo(12.0 * scaleX, 4.5 * scaleY)  // Right ear
      ..lineTo(13.0 * scaleX, 8.5 * scaleY)  // Forehead
      ..lineTo(18.3 * scaleX, 10.0 * scaleY) // Snout top
      ..lineTo(18.7 * scaleX, 12.5 * scaleY) // Snout tip
      ..lineTo(17.0 * scaleX, 13.5 * scaleY) // Chin
      ..lineTo(14.0 * scaleX, 13.5 * scaleY) // Jaw
      ..lineTo(14.5 * scaleX, 21.0 * scaleY) // Chest
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, outlinePaint);

    // Eye dot
    final Paint eyePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(12.5 * scaleX, 11.0 * scaleY), 0.9 * scaleX, eyePaint);

    // Inner ear detail
    final Paint detailPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(8.5 * scaleX, 6.0 * scaleY),
      Offset(9.5 * scaleX, 8.0 * scaleY),
      detailPaint,
    );
  }

  @override
  bool shouldRepaint(covariant TomsllamaLogoPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}

typedef GemlamaLogoPainter = TomsllamaLogoPainter;

class TomsllamaLogo extends StatefulWidget {
  final double size;
  final bool animate;
  
  const TomsllamaLogo({super.key, this.size = 20.0, this.animate = true});

  @override
  State<TomsllamaLogo> createState() => _TomsllamaLogoState();
}

class _TomsllamaLogoState extends State<TomsllamaLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.animate ? _scaleAnimation.value : 1.0,
          child: child,
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: TomsllamaLogoPainter(accentColor: appColors.accent),
        ),
      ),
    );
  }
}

typedef GemlamaLogo = TomsllamaLogo;
