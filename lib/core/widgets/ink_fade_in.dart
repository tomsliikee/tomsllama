import 'package:flutter/material.dart';

import '../constants/app_tokens.dart';

/// New content settles onto the page like ink: a 4px rise while it fades in.
/// Plays once when the widget first appears; pass [enabled] false to show
/// content that is merely being scrolled back into view without replaying it.
class InkFadeIn extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Duration delay;

  const InkFadeIn({
    super.key,
    required this.child,
    this.enabled = true,
    this.delay = Duration.zero,
  });

  @override
  State<InkFadeIn> createState() => _InkFadeInState();
}

class _InkFadeInState extends State<InkFadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.slow);
    _curve = CurvedAnimation(parent: _controller, curve: AppMotion.standard);
    if (!widget.enabled) {
      _controller.value = 1.0;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 4.0 * (1.0 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
