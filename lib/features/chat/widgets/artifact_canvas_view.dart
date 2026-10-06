import 'package:flutter/material.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';

class ArtifactCanvasView extends StatelessWidget {
  final Widget chatPanel;
  final Widget? canvasPanel;
  final bool isCanvasOpen;
  final VoidCallback? onCloseCanvas;
  final VoidCallback? onCopy;
  final String? language;

  const ArtifactCanvasView({
    super.key,
    required this.chatPanel,
    this.canvasPanel,
    this.isCanvasOpen = false,
    this.onCloseCanvas,
    this.onCopy,
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
          duration: AppMotion.slow,
          curve: AppMotion.standard,
          width: isCanvasOpen ? MediaQuery.of(context).size.width * 0.5 : 0.0,
          child: isCanvasOpen
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 12.0),
                  child: _CanvasWrapper(
                    onClose: onCloseCanvas,
                    onCopy: onCopy,
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
  final VoidCallback? onCopy;
  final AppThemeExtension appColors;
  final String? language;

  const _CanvasWrapper({
    required this.child,
    this.onClose,
    this.onCopy,
    required this.appColors,
    this.language,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Canvas Header Row: single pill for "Canvas" in menu bar style + copy pill + close pill
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 5.0),
              decoration: BoxDecoration(
                color: appColors.surface,
                border: Border.all(color: appColors.borderSubtle),
                borderRadius: BorderRadius.circular(AppRadii.panel),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.terminal,
                    size: 14.0,
                    color: appColors.accent,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    I18n.canvas,
                    style: AppTypography.label.copyWith(
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
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onCopy != null) ...[
              const SizedBox(width: 8.0),
              _CanvasCopyPill(
                onCopy: onCopy,
                appColors: appColors,
              ),
            ],
            const Spacer(),
            if (onClose != null)
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(AppRadii.panel),
                child: Container(
                  height: 28.0,
                  width: 28.0,
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    border: Border.all(color: appColors.borderSubtle),
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    AppIcons.close,
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
              borderRadius: BorderRadius.circular(AppRadii.panel),
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

class _CanvasCopyPill extends StatefulWidget {
  final VoidCallback? onCopy;
  final AppThemeExtension appColors;

  const _CanvasCopyPill({
    required this.onCopy,
    required this.appColors,
  });

  @override
  State<_CanvasCopyPill> createState() => _CanvasCopyPillState();
}

class _CanvasCopyPillState extends State<_CanvasCopyPill> {
  bool _copied = false;
  bool _isHovered = false;

  void _handleCopy() {
    widget.onCopy?.call();
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = widget.appColors;
    final color = _copied
        ? appColors.accent
        : (_isHovered ? appColors.accent : appColors.textSecondary);

    return InkWell(
      onTap: _handleCopy,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      onHover: (hovered) => setState(() => _isHovered = hovered),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: _isHovered ? appColors.accentSubtle : appColors.surface,
          border: Border.all(
            color: _isHovered ? appColors.accent.withValues(alpha: 0.3) : appColors.borderSubtle,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? AppIcons.check : AppIcons.copy,
              size: 13.0,
              color: color,
            ),
            const SizedBox(width: 4.5),
            Text(
              _copied ? I18n.copied : I18n.copy,
              style: AppTypography.label.copyWith(
                color: color,
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
