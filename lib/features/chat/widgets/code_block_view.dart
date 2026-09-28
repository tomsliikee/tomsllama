import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/darcula.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';
import '../controllers/chat_controller.dart';

class CodeBlockView extends ConsumerStatefulWidget {
  final String code;
  final String language;

  const CodeBlockView({
    super.key,
    required this.code,
    required this.language,
  });

  @override
  ConsumerState<CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends ConsumerState<CodeBlockView> {
  bool _copied = false;

  void _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (mounted) setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _openInCanvas() {
    ref.read(chatProvider.notifier).openInCanvas(widget.code, widget.language);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final Map<String, TextStyle> codeTheme = Map.from(isDark ? darculaTheme : githubTheme);
    codeTheme['root'] = TextStyle(
      backgroundColor: Colors.transparent,
      color: appColors.textPrimary,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Floating Pill Row
          Row(
            children: [
              // Language Floating Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
                decoration: BoxDecoration(
                  color: appColors.surface,
                  border: Border.all(color: appColors.borderSubtle, width: 1.0),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.code_rounded,
                      size: 13.0,
                      color: appColors.accent,
                    ),
                    const SizedBox(width: 5.0),
                    Text(
                      widget.language.isEmpty ? 'code' : widget.language,
                      style: AppTypography.code.copyWith(
                        color: appColors.accent,
                        fontWeight: FontWeight.w500,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Separate Pill 1: Split-View Canvas
              _CodeActionPill(
                label: I18n.splitViewCanvas,
                icon: Icons.splitscreen_outlined,
                onTap: _openInCanvas,
                appColors: appColors,
              ),
              const SizedBox(width: 8.0),
              // Separate Pill 2: Copy
              _CodeActionPill(
                label: _copied ? I18n.copied : I18n.copy,
                icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                onTap: _copyToClipboard,
                isActive: _copied,
                appColors: appColors,
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          // Code Box Container: beautifully rounded with 18px radius
          Container(
            decoration: BoxDecoration(
              color: appColors.codeBackground,
              border: Border.all(color: appColors.borderSubtle, width: 1.0),
              borderRadius: BorderRadius.circular(18.0),
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(14.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                widget.code.trimRight(),
                language: widget.language.isEmpty ? 'plaintext' : widget.language,
                theme: codeTheme,
                textStyle: AppTypography.code.copyWith(
                  fontSize: 13.0,
                  height: 1.5,
                  color: appColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeActionPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final AppThemeExtension appColors;

  const _CodeActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    required this.appColors,
  });

  @override
  State<_CodeActionPill> createState() => _CodeActionPillState();
}

class _CodeActionPillState extends State<_CodeActionPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final appColors = widget.appColors;

    final color = widget.isActive
        ? appColors.accent
        : (_isHovered ? appColors.accent : appColors.textSecondary);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16.0),
      onHover: (hovered) => setState(() => _isHovered = hovered),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
        decoration: BoxDecoration(
          color: _isHovered ? appColors.accentSubtle : appColors.surface,
          border: Border.all(
            color: _isHovered
                ? appColors.accent.withValues(alpha: 0.3)
                : appColors.borderSubtle,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 12.5, color: color),
            const SizedBox(width: 5.0),
            Text(
              widget.label,
              style: AppTypography.uiControl.copyWith(
                color: color,
                fontSize: 11.5,
                fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
