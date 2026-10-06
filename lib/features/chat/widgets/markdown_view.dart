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
            height: 1.65,
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
        pPadding: EdgeInsets.zero,
        blockSpacing: isThinkBlock ? 8.0 : 12.0,
        // Emphasis by weight for strong and by slant for em, never both.
        strong: baseTextStyle.copyWith(fontWeight: FontWeight.w600),
        em: baseTextStyle.copyWith(fontStyle: FontStyle.italic),
        a: baseTextStyle.copyWith(
          color: appColors.accent,
          decoration: TextDecoration.underline,
          decorationColor: appColors.accent.withValues(alpha: 0.4),
        ),
        h1: AppTypography.title.copyWith(color: appColors.textPrimary, fontSize: 22.0),
        h1Padding: const EdgeInsets.only(top: 6.0),
        h2: AppTypography.title.copyWith(color: appColors.textPrimary),
        h2Padding: const EdgeInsets.only(top: 6.0),
        h3: AppTypography.body.copyWith(color: appColors.textPrimary, fontWeight: FontWeight.w600, height: 1.4),
        h3Padding: const EdgeInsets.only(top: 4.0),
        listBullet: baseTextStyle.copyWith(color: appColors.textSecondary),
        listIndent: 22.0,
        listBulletPadding: const EdgeInsets.only(right: 6.0),
        blockquote: baseTextStyle.copyWith(color: appColors.textSecondary, fontStyle: FontStyle.italic),
        blockquotePadding: const EdgeInsets.only(left: 14.0, top: 2.0, bottom: 2.0),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: appColors.border, width: 2.0)),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: appColors.border, width: 1.0)),
        ),
        tableHead: AppTypography.label.copyWith(color: appColors.textSecondary, fontWeight: FontWeight.w500),
        tableBody: baseTextStyle.copyWith(fontSize: isThinkBlock ? 12.0 : 15.0, height: 1.4),
        tableBorder: TableBorder(
          horizontalInside: BorderSide(color: appColors.borderSubtle, width: 1.0),
          bottom: BorderSide(color: appColors.borderSubtle, width: 1.0),
        ),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        code: AppTypography.code.copyWith(
          backgroundColor: appColors.codeBackground,
          color: appColors.textPrimary,
          fontSize: isThinkBlock ? 11.5 : 13.5,
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
          textStyle: TextStyle(fontSize: 16.5, color: preferredStyle?.color),
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
      textStyle: TextStyle(fontSize: 16.5, color: preferredStyle?.color),
    );
  }
}
