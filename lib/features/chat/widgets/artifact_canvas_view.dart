import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';

class ArtifactCanvasView extends StatelessWidget {
  final Widget chatPanel;
  final Widget? canvasPanel;
  final bool isCanvasOpen;
  final VoidCallback? onCloseCanvas;
  final String? language;

  const ArtifactCanvasView({
    super.key,
    required this.chatPanel,
    this.canvasPanel,
    this.isCanvasOpen = false,
    this.onCloseCanvas,
    this.language,
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
          
        // Right: Canvas Panel (takes 50% width if open, 0 if closed)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: isCanvasOpen ? MediaQuery.of(context).size.width * 0.5 : 0.0,
          child: isCanvasOpen
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 12.0),
                  child: _CanvasWrapper(
                    onClose: onCloseCanvas,
                    appColors: appColors,
                    language: language,
                    child: canvasPanel ?? const SizedBox.shrink(),
                  ),
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
  final String? language;

  const _CanvasWrapper({
    required this.child,
    this.onClose,
    required this.appColors,
    this.language,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Canvas Header Row: single pill for "Canvas" in menu bar style + close pill
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 5.0),
              decoration: BoxDecoration(
                color: appColors.surface,
                border: Border.all(color: appColors.borderSubtle),
                borderRadius: BorderRadius.circular(18.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.terminal,
                    size: 14.0,
                    color: appColors.accent,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    'Canvas',
                    style: AppTypography.uiControl.copyWith(
                      color: appColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.0,
                    ),
                  ),
                  if (language != null && language!.isNotEmpty) ...[
                    const SizedBox(width: 6.0),
                    Text(
                      language!,
                      style: AppTypography.code.copyWith(
                        color: appColors.textSecondary,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            if (onClose != null)
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(18.0),
                child: Container(
                  height: 28.0,
                  width: 28.0,
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    border: Border.all(color: appColors.borderSubtle),
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close,
                    size: 14.0,
                    color: appColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8.0),
        // Content area: in its own area with rounded corners indented with padding just like the main page
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: appColors.surface,
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: appColors.borderSubtle, width: 1.0),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ],
    );
  }
}
