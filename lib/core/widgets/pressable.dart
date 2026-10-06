import 'package:flutter/material.dart';

import '../constants/app_tokens.dart';

/// The one way a control reacts to the pointer: it reports hover so the caller
/// can tint itself, and gives a little under the press with a spring.
///
/// Every chip, pill and icon button goes through this so they all feel the same.
class Pressable extends StatefulWidget {
  final VoidCallback? onTap;
  final String? tooltip;
  final Widget Function(BuildContext context, bool isHovered, bool isPressed) builder;

  const Pressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.tooltip,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _isHovered = false;
  bool _isPressed = false;

  bool get _enabled => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    Widget child = MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: _isPressed ? AppMotion.fast : AppMotion.base,
          curve: _isPressed ? AppMotion.standard : AppMotion.spring,
          child: widget.builder(context, _enabled && _isHovered, _isPressed),
        ),
      ),
    );

    if (widget.tooltip != null) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}
