import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ArtifactCanvasView extends StatelessWidget {
  final Widget chatPanel;
  final Widget? canvasPanel;
  final bool isCanvasOpen;
  final VoidCallback? onCloseCanvas;

  const ArtifactCanvasView({
    super.key,
    required this.chatPanel,
    this.canvasPanel,
    this.isCanvasOpen = false,
    this.onCloseCanvas,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Row(
      children: [
        // Left: Chat Panel (takes full width if canvas is closed, 50% if open)
        Expanded(
          flex: 1,
          child: chatPanel,
        ),
        
        // Vertical Divider
        if (isCanvasOpen)
          Container(
            width: 1.0,
            color: appColors.border,
          ),
          
        // Right: Canvas Panel (takes 50% width if open, 0 if closed)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: isCanvasOpen ? MediaQuery.of(context).size.width * 0.5 : 0.0,
          child: isCanvasOpen
              ? _CanvasWrapper(
                  onClose: onCloseCanvas,
                  appColors: appColors,
                  child: canvasPanel ?? const SizedBox.shrink(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _CanvasWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onClose;
  final AppThemeExtension appColors;

  const _CanvasWrapper({
    required this.child,
    this.onClose,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: appColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Canvas Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: appColors.border, width: 1.0)),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, size: 16.0, color: appColors.textSecondary),
                const SizedBox(width: 8.0),
                Text(
                  'Canvas',
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 18.0,
                  color: appColors.textSecondary,
                  onPressed: onClose,
                  splashRadius: 20.0,
                ),
              ],
            ),
          ),
          // Canvas Content
          Expanded(child: child),
        ],
      ),
    );
  }
}
