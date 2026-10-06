import 'package:flutter/material.dart';
import '../../../core/constants/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_highlight/flutter_highlight.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/widgets/app_pill.dart';
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

  /// Syntax colours drawn from the theme: weight for structure, the accent for
  /// literal values, grey italics for comments. Two inks, like a printed listing.
  static Map<String, TextStyle> _highlightTheme(AppThemeExtension colors) {
    final strong = TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600);
    final value = TextStyle(color: colors.accent);
    final quiet = TextStyle(color: colors.textSecondary);
    return {
      'root': TextStyle(backgroundColor: Colors.transparent, color: colors.textPrimary),
      'keyword': strong,
      'selector-tag': strong,
      'section': strong,
      'name': strong,
      'tag': quiet,
      'built_in': TextStyle(color: colors.textPrimary),
      'type': TextStyle(color: colors.textPrimary),
      'title': TextStyle(color: colors.textPrimary),
      'string': value,
      'number': value,
      'literal': value,
      'symbol': value,
      'regexp': value,
      'bullet': value,
      'attr': quiet,
      'attribute': quiet,
      'meta': quiet,
      'params': TextStyle(color: colors.textPrimary),
      'comment': TextStyle(color: colors.textSecondary, fontStyle: FontStyle.italic),
      'quote': TextStyle(color: colors.textSecondary, fontStyle: FontStyle.italic),
      'deletion': quiet,
      'addition': value,
      'emphasis': const TextStyle(fontStyle: FontStyle.italic),
      'strong': const TextStyle(fontWeight: FontWeight.w600),
    };
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final codeTheme = _highlightTheme(appColors);

    final languagePill = Container(
      height: 28.0,
      padding: const EdgeInsets.symmetric(horizontal: 11.0),
      decoration: BoxDecoration(
        color: appColors.codeBackground,
        border: Border.all(color: appColors.borderSubtle, width: 1.0),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.code, size: 14.0, color: appColors.accent),
          const SizedBox(width: 6.0),
          Text(
            widget.language.isEmpty ? 'code' : widget.language,
            style: AppTypography.label.copyWith(color: appColors.accent, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

    final splitViewPill = AppPill(
      label: I18n.splitViewCanvas,
      icon: AppIcons.canvas,
      fill: appColors.codeBackground,
      onTap: _openInCanvas,
    );

    final copyPill = AppPill(
      label: _copied ? I18n.copied : I18n.copy,
      icon: _copied ? AppIcons.check : AppIcons.copy,
      fill: appColors.codeBackground,
      isActive: _copied,
      onTap: _copyToClipboard,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header pills: language left, actions right; they wrap when the pane is narrow.
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 380) {
                return Row(
                  children: [
                    languagePill,
                    const Spacer(),
                    splitViewPill,
                    const SizedBox(width: 8.0),
                    copyPill,
                  ],
                );
              }
              return Wrap(
                spacing: 8.0,
                runSpacing: 6.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [languagePill, splitViewPill, copyPill],
              );
            },
          ),

          const SizedBox(height: 8.0),

          Container(
            decoration: BoxDecoration(
              color: appColors.codeBackground,
              border: Border.all(color: appColors.borderSubtle, width: 1.0),
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                widget.code.trimRight(),
                language: widget.language.isEmpty ? 'plaintext' : widget.language,
                theme: codeTheme,
                textStyle: AppTypography.code.copyWith(color: appColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
