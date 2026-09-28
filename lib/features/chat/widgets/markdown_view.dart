import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import 'code_block_view.dart';

class MarkdownView extends StatelessWidget {
  final String data;
  final bool isThinkBlock;

  const MarkdownView({
    super.key,
    required this.data,
    this.isThinkBlock = false,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    final baseTextStyle = isThinkBlock
        ? AppTypography.code.copyWith(
            color: appColors.textSecondary,
            fontSize: 12.0,
            height: 1.6,
          )
        : AppTypography.body.copyWith(
            color: appColors.textPrimary,
            fontSize: 16.5,
            height: 1.7,
          );

    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: baseTextStyle,
        strong: AppTypography.bodyItalic.copyWith(
          color: appColors.textPrimary,
          fontFamily: AppTypography.serifFamily,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          fontSize: isThinkBlock ? 12.0 : 16.5,
        ),
        em: AppTypography.bodyItalic.copyWith(
          color: appColors.textPrimary,
          fontFamily: AppTypography.serifFamily,
          fontStyle: FontStyle.italic,
          fontSize: isThinkBlock ? 12.0 : 16.5,
        ),
        h1: AppTypography.headline.copyWith(color: appColors.textPrimary, fontSize: 24),
        h2: AppTypography.headline.copyWith(fontSize: 20, color: appColors.textPrimary),
        h3: AppTypography.headline.copyWith(fontSize: 17, color: appColors.textPrimary),
        code: AppTypography.code.copyWith(
          backgroundColor: appColors.codeBackground,
          color: appColors.textPrimary,
          fontSize: 13.0,
        ),
        codeblockDecoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        codeblockPadding: EdgeInsets.zero,
      ),
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          // No EmojiSyntax as per Anti-AI-Slop rule
          LatexBlockSyntax(),
          LatexInlineSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
      builders: {
        'code': CodeBlockBuilder(),
        'latexBlock': LatexBlockBuilder(),
        'latexInline': LatexInlineBuilder(),
      },
    );
  }
}

// --- LaTeX Syntaxes ---

class LatexBlockSyntax extends md.InlineSyntax {
  LatexBlockSyntax() : super(r'\$\$([^\$]+?)\$\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('latexBlock', match[1]!));
    return true;
  }
}

class LatexInlineSyntax extends md.InlineSyntax {
  // Only match $...$ when preceded and followed by non-space/digits to avoid matching currency
  LatexInlineSyntax() : super(r'(?<![\w\$])\$([^\$]+?)\$(?![\w\$])');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('latexInline', match[1]!));
    return true;
  }
}

// --- Custom Builders ---

class CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.children != null &&
        element.children!.isNotEmpty &&
        element.children!.first is md.Text) {
      final text = element.textContent;
      if (text.contains('\n')) {
        String language = '';
        if (element.attributes.containsKey('class')) {
          final className = element.attributes['class']!;
          if (className.startsWith('language-')) {
            language = className.substring(9);
          }
        }
        return CodeBlockView(code: text.trim(), language: language);
      }
    }
    return null;
  }
}

class LatexBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Center(
        child: Math.tex(
          element.textContent,
          textStyle: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}

class LatexInlineBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Math.tex(
      element.textContent,
      textStyle: const TextStyle(fontSize: 15),
    );
  }
}
