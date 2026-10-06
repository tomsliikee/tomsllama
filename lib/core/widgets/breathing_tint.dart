import 'package:flutter/material.dart';

import '../constants/app_tokens.dart';

/// Lays a tint behind [child] that slowly swells and fades while [active],
/// at the pace of the logo's breath. Used to show that something is working
/// without adding a mark to it.
class BreathingTint extends StatefulWidget {
  final bool active;
  final Color color;
  final double maxOpacity;
  final double radius;
  final Widget child;

  const BreathingTint({
    super.key,
    required this.active,
    required this.color,
    required this.child,
    this.maxOpacity = 0.10,
    this.radius = AppRadii.control,
  });

  @override
  State<BreathingTint> createState() => _BreathingTintState();
}

class _BreathingTintState extends State<BreathingTint> with SingleTickerProviderStateMixin {
  // Created on first use: most rows never breathe and should not hold a ticker.
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(BreathingTint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) _sync();
  }

  void _sync() {
    if (widget.active) {
      _controller ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1750));
      _controller!.repeat(reverse: true);
    } else {
      // Breathe out to nothing rather than cutting off.
      _controller?.animateTo(0.0, duration: AppMotion.slow, curve: AppMotion.standard);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final breath = Curves.easeInOutSine.transform(controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: widget.maxOpacity * breath),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
