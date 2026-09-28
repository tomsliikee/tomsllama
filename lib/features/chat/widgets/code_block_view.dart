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
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: appColors.codeBackground,
        border: Border.all(color: appColors.borderSubtle, width: 1.0),
        borderRadius: BorderRadius.circular(12.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar (1:1 style_preview.html)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
            decoration: BoxDecoration(
              color: appColors.surface, // #FFFFFF in Claude and Pond
              border: Border(bottom: BorderSide(color: appColors.borderSubtle, width: 1.0)),
            ),
            child: Row(
              children: [
                // Language Badge
                Text(
                  widget.language.isEmpty ? 'code' : widget.language,
                  style: AppTypography.code.copyWith(
                    color: appColors.accent,
                    fontWeight: FontWeight.w500,
                    fontSize: 11.0,
                  ),
                ),
                const Spacer(),
                
                // Split-View Canvas Button
                _CodeActionBtn(
                  label: I18n.splitViewCanvas,
                  onTap: _openInCanvas,
                ),
                const SizedBox(width: 12.0),

                // Copy Button
                _CodeActionBtn(
                  label: _copied ? I18n.copied : I18n.copy,
                  onTap: _copyToClipboard,
                  isActive: _copied,
                ),
              ],
            ),
          ),
          
          // Code Body
          Padding(
            padding: const EdgeInsets.all(12.0),
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

class _CodeActionBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _CodeActionBtn({
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_CodeActionBtn> createState() => _CodeActionBtnState();
}

class _CodeActionBtnState extends State<_CodeActionBtn> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    final color = widget.isActive
        ? appColors.accent
        : (_isHovered ? appColors.accent : appColors.textSecondary);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: AppTypography.code.copyWith(
            color: color,
            fontSize: 11.0,
            fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
