import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/widgets/breathing_tint.dart';
import 'package:tomsllama/core/constants/app_icons.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/core/models/conversation.dart';
import 'package:tomsllama/core/services/localization_service.dart';
import 'package:tomsllama/features/sidebar/widgets/sidebar_view.dart';

void main() {
  testWidgets('SidebarView renders history and triggers callbacks', (WidgetTester tester) async {
    final now = DateTime.now();
    final conversations = [
      Conversation(id: '1', title: 'Chat 1', createdAt: now, updatedAt: now),
      Conversation(id: '2', title: 'Chat 2', createdAt: now, updatedAt: now),
    ];
    
    String? selectedId;
    bool newChatClicked = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: Scaffold(
          body: SidebarView(
            conversations: conversations,
            activeConversationId: '1',
            searchController: TextEditingController(),
            onSearchChanged: (_) {},
            onSearchClear: () {},
            onNewChat: () => newChatClicked = true,
            onSelectChat: (id) => selectedId = id,
            onDeleteChat: (_) {},
            onExportChat: (_) {},
          ),
        ),
      ),
    );

    // Verify history section header and new chat button
    expect(find.text(I18n.history), findsOneWidget);
    expect(find.text(I18n.newChatTitle), findsOneWidget);
    expect(find.text(I18n.ctrlN), findsOneWidget);

    // Verify chat items
    expect(find.text('Chat 1'), findsOneWidget);
    expect(find.text('Chat 2'), findsOneWidget);

    // Test select chat
    await tester.tap(find.text('Chat 2'));
    await tester.pumpAndSettle();
    expect(selectedId, '2');

    // Test new chat
    await tester.tap(find.text(I18n.newChatTitle));
    await tester.pumpAndSettle();
    expect(newChatClicked, isTrue);
  });

  testWidgets('SidebarView displays pinned conversation icon and triggers pin callback', (WidgetTester tester) async {
    final now = DateTime.now();
    final conversations = [
      Conversation(id: '1', title: 'Pinned Chat', createdAt: now, updatedAt: now, isPinned: true),
      Conversation(id: '2', title: 'Regular Chat', createdAt: now, updatedAt: now, isPinned: false),
    ];

    String? pinnedToggledId;

    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: Scaffold(
          body: SidebarView(
            conversations: conversations,
            activeConversationId: '1',
            onNewChat: () {},
            onSelectChat: (_) {},
            onTogglePinChat: (id) => pinnedToggledId = id,
          ),
        ),
      ),
    );

    // Pinned chat should have push pin icon visible
    expect(find.byIcon(AppIcons.pinned), findsOneWidget);

    // Tap pin icon
    await tester.tap(find.byIcon(AppIcons.pinned));
    await tester.pumpAndSettle();
    expect(pinnedToggledId, '1');
  });

  testWidgets('a generating chat breathes and stops when the answer is done', (WidgetTester tester) async {
    final now = DateTime.now();
    final conversations = [
      Conversation(id: 'a', title: 'Busy chat', createdAt: now, updatedAt: now),
      Conversation(id: 'b', title: 'Idle chat', createdAt: now, updatedAt: now),
    ];
    Widget build(Set<String> generating) => MaterialApp(
          theme: claudeTheme,
          home: Scaffold(
            body: SidebarView(
              conversations: conversations,
              activeConversationId: 'b',
              generatingConversationIds: generating,
              onNewChat: () {},
              onSelectChat: (_) {},
            ),
          ),
        );

    Finder breathingOf(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(BreathingTint));
    double tintOf(String title) {
      // The tint is the first box inside the breathing layer; the row's own fill comes after it.
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: breathingOf(title), matching: find.byType(DecoratedBox)).first,
      );
      return (box.decoration as BoxDecoration).color!.a;
    }

    await tester.pumpWidget(build({'a'}));
    await tester.pump(const Duration(milliseconds: 1750));
    expect(tintOf('Busy chat'), greaterThan(0.05));
    expect(tester.widget<BreathingTint>(breathingOf('Idle chat')).active, isFalse);

    await tester.pumpWidget(build(const {}));
    await tester.pumpAndSettle();
    expect(tintOf('Busy chat'), 0.0);
  });
}
