import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/core/services/localization_service.dart';
import 'package:tomsllama/features/chat/widgets/chat_viewport.dart';
import 'package:tomsllama/features/shell/widgets/tomsllama_logo.dart';

void main() {
  testWidgets('ChatViewport renders enlarged logo, title and subtitle in empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: const Scaffold(
          body: ChatViewport(
            messages: [],
            isGenerating: false,
          ),
        ),
      ),
    );

    // Verify logo with enlarged size 46.0 and idle animation enabled
    final logoFinder = find.byType(TomsllamaLogo);
    expect(logoFinder, findsOneWidget);
    final logoWidget = tester.widget<TomsllamaLogo>(logoFinder);
    expect(logoWidget.size, 46.0);
    expect(logoWidget.enableIdleAnimation, isTrue);

    // Verify title 'tomsllama' with enlarged 26.4 font
    final titleFinder = find.text('tomsllama');
    expect(titleFinder, findsOneWidget);
    final titleText = tester.widget<Text>(titleFinder);
    expect(titleText.style?.fontSize, 26.4);

    // Verify subtitle with enlarged 15.6 font
    final subtitleFinder = find.text(I18n.subtitle);
    expect(subtitleFinder, findsOneWidget);
    final subtitleText = tester.widget<Text>(subtitleFinder);
    expect(subtitleText.style?.fontSize, 15.6);
  });
}
