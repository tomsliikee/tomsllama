import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/constants/app_typography.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/core/services/localization_service.dart';
import 'package:tomsllama/core/models/message.dart';
import 'package:tomsllama/features/chat/widgets/chat_viewport.dart';
import 'package:tomsllama/core/widgets/tomsllama_logo.dart';

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

    // Verify logo with enlarged size 53.0 and idle animation enabled
    final logoFinder = find.byType(TomsllamaLogo);
    expect(logoFinder, findsOneWidget);
    final logoWidget = tester.widget<TomsllamaLogo>(logoFinder);
    expect(logoWidget.size, 53.0);
    expect(logoWidget.enableIdleAnimation, isTrue);

    // Verify title 'tomsllama' with enlarged 30.0 font
    final titleFinder = find.text('tomsllama');
    expect(titleFinder, findsOneWidget);
    final titleText = tester.widget<Text>(titleFinder);
    expect(titleText.style?.fontSize, 30.0);

    // Verify subtitle uses the reading size of the type scale
    final subtitleFinder = find.text(I18n.subtitle);
    expect(subtitleFinder, findsOneWidget);
    final subtitleText = tester.widget<Text>(subtitleFinder);
    expect(subtitleText.style?.fontSize, AppTypography.body.fontSize);
  });

  testWidgets('ChatViewport renders SelectionArea with messages', (WidgetTester tester) async {
    final now = DateTime.now();
    final messages = [
      Message(
        id: 'msg-1',
        conversationId: 'conv-1',
        role: 'user',
        content: 'Hello, what is Dart?',
        createdAt: now,
      ),
      Message(
        id: 'msg-2',
        conversationId: 'conv-1',
        role: 'assistant',
        content: 'Dart is an object-oriented language.',
        createdAt: now,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: Scaffold(
          body: ChatViewport(
            messages: messages,
            isGenerating: false,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify SelectionArea exists wrapping the message list
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('Hello, what is Dart?'), findsOneWidget);
    expect(find.textContaining('Dart is an object-oriented language.'), findsOneWidget);
  });
}
