import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/darcula.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import '../../../core/constants/app_typography.dart';

Map<String, TextStyle> getHighlightCodeTheme(bool isDark, Color textColor) {
  final Map<String, TextStyle> codeTheme = Map.from(isDark ? darculaTheme : githubTheme);
  codeTheme['root'] = TextStyle(
    backgroundColor: Colors.transparent,
    color: textColor,
  );
  return codeTheme;
}

class SyntaxHighlightView extends StatelessWidget {
  final String source;
  final String? language;
  final Map<String, TextStyle> theme;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;

  const SyntaxHighlightView(
    this.source, {
    super.key,
    this.language,
    this.theme = const {},
    this.textStyle,
    this.padding,
  });

  List<TextSpan> _convert(List<Node> nodes) {
    final List<TextSpan> spans = [];
    var currentSpans = spans;
    final List<List<TextSpan>> stack = [];

    void traverse(Node node) {
      if (node.value != null) {
        currentSpans.add(
          node.className == null
              ? TextSpan(text: node.value)
              : TextSpan(text: node.value, style: theme[node.className!]),
        );
      } else if (node.children != null) {
        final List<TextSpan> tmp = [];
        currentSpans.add(TextSpan(children: tmp, style: theme[node.className!]));
        stack.add(currentSpans);
        currentSpans = tmp;

        for (final n in node.children!) {
          traverse(n);
          if (n == node.children!.last) {
            currentSpans = stack.isEmpty ? spans : stack.removeLast();
          }
        }
      }
    }

    for (final node in nodes) {
      traverse(node);
    }

    return spans;
  }

  static String? normalizeLanguage(String? lang) {
    if (lang == null || lang.isEmpty) return null;
    final lower = lang.toLowerCase().trim();
    if (lower == 'md' || lower == 'markdown' || lower == 'mkd') return 'markdown';
    return lower;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = const TextStyle(
      fontFamily: AppTypography.monoFamily,
    ).merge(textStyle);

    final normalizedLang = normalizeLanguage(language);
    List<Node> nodes;
    try {
      final result = highlight.parse(source, language: normalizedLang);
      nodes = result.nodes ?? [];
    } catch (_) {
      nodes = [Node(value: source)];
    }

    return Container(
      padding: padding,
      child: Text.rich(
        TextSpan(
          style: effectiveStyle,
          children: _convert(nodes),
        ),
      ),
    );
  }
}
