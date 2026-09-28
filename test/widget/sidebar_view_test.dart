import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text(I18n.newChat), findsOneWidget);
    expect(find.text(I18n.ctrlN), findsOneWidget);

    // Verify chat items
    expect(find.text('Chat 1'), findsOneWidget);
    expect(find.text('Chat 2'), findsOneWidget);

    // Test select chat
    await tester.tap(find.text('Chat 2'));
    await tester.pumpAndSettle();
    expect(selectedId, '2');

    // Test new chat
    await tester.tap(find.text(I18n.newChat));
    await tester.pumpAndSettle();
    expect(newChatClicked, isTrue);
  });
}
