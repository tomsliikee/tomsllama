import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/models/conversation.dart';
import 'package:tomsllama/core/models/workspace.dart';
import 'package:tomsllama/core/models/workspace_context_file.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/features/workspace/widgets/cute_llama_file_mascot.dart';
import 'package:tomsllama/features/workspace/widgets/workspace_hub_view.dart';

void main() {
  testWidgets('WorkspaceHubView renders prompt, files, cute mascot, composer and chats', (WidgetTester tester) async {
    final now = DateTime.now();
    final workspace = Workspace(
      id: 'ws_test_1',
      name: 'Erlebnisplaner',
      prompt: 'Du bist der Erlebnisplaner Architekt.',
      createdAt: now,
      updatedAt: now,
    );

    final files = [
      WorkspaceContextFile(
        id: 'file_1',
        workspaceId: 'ws_test_1',
        filePath: '/test/spec.md',
        fileName: 'spec.md',
        fileSize: 1024,
        content: '# Architecture Spec',
        estimatedTokens: 250,
        createdAt: now,
      ),
    ];

    final chats = [
      Conversation(
        id: 'conv_1',
        title: 'Datenbank Schema Planung',
        createdAt: now,
        updatedAt: now,
        persona: 'Architect',
        workspaceId: 'ws_test_1',
      ),
    ];

    String? startedPrompt;
    String? openedChatId;

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: claudeTheme,
          home: Scaffold(
            body: WorkspaceHubView(
              workspace: workspace,
              files: files,
              chats: chats,
              onStartChat: (prompt, model, persona) {
                startedPrompt = prompt;
              },
              onOpenChat: (id) {
                openedChatId = id;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify workspace name & mascot
    expect(find.text('Erlebnisplaner'), findsWidgets);
    expect(find.byType(CuteLlamaFileMascot), findsOneWidget);

    // Verify context file pill
    expect(find.text('spec.md'), findsOneWidget);

    // Verify chat item
    expect(find.text('Datenbank Schema Planung'), findsOneWidget);

    // Tap existing chat
    await tester.tap(find.text('Datenbank Schema Planung'));
    expect(openedChatId, 'conv_1');

    // Type into central input field and submit
    final inputField = find.byType(TextField).last;
    await tester.enterText(inputField, 'Erstelle das Schema für Events');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(startedPrompt, 'Erstelle das Schema für Events');
  });
}
