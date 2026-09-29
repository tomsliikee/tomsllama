import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/core/services/localization_service.dart';
import 'package:tomsllama/core/models/workspace_info.dart';
import 'package:tomsllama/core/models/attached_file.dart';
import 'package:tomsllama/features/chat/controllers/workspace_controller.dart';
import 'package:tomsllama/features/chat/controllers/chat_controller.dart';
import 'package:tomsllama/features/chat/widgets/composer_bar.dart';

void main() {
  testWidgets('ComposerBar renders and triggers onSend on enter', (WidgetTester tester) async {
    String? sentText;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: claudeTheme,
          home: Scaffold(
            body: ComposerBar(
              isGenerating: false,
              activePersonaName: 'Architect',
              onSend: (text) => sentText = text,
              onStop: () {},
              onPersonaTap: () {},
            ),
          ),
        ),
      ),
    );

    // Verify persona chip exists
    expect(find.text('Architect'), findsOneWidget);

    // Find text field
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    // Enter text
    await tester.enterText(textField, 'Hello World');
    await tester.pumpAndSettle();

    // Verify Send button appears (hasText logic)
    expect(find.text(I18n.send), findsOneWidget);

    // Simulate Enter key
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(sentText, 'Hello World');
  });

  testWidgets('ComposerBar opens scrollable persona menu with primary and additional sections', (WidgetTester tester) async {
    String? selectedPersona;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: claudeTheme,
          home: Scaffold(
            body: ComposerBar(
              isGenerating: false,
              activePersonaName: 'Standard',
              onSend: (_) {},
              onStop: () {},
              onPersonaTap: () {},
              onSelectPersona: (p) => selectedPersona = p,
            ),
          ),
        ),
      ),
    );

    // Tap persona chip to open dropdown
    await tester.tap(find.text('Standard'));
    await tester.pumpAndSettle();

    // Verify header and primary role are immediately in view
    expect(find.text(I18n.roleAndPrompt), findsOneWidget);
    expect(find.text(I18n.isGerman ? 'Senior-Entwickler' : 'Senior Coder'), findsOneWidget);

    // Scroll down to reveal the additional section
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(find.text(I18n.isGerman ? 'ZUSÄTZLICHE' : 'ADDITIONAL'), findsOneWidget);
    expect(find.text(I18n.isGerman ? 'Tiefenanalytiker' : 'Deep Analyst'), findsOneWidget);

    // Tap a role
    await tester.tap(find.text(I18n.isGerman ? 'Tiefenanalytiker' : 'Deep Analyst'));
    await tester.pumpAndSettle();

    expect(selectedPersona, I18n.isGerman ? 'Tiefenanalytiker' : 'Deep Analyst');
  });

  testWidgets('ComposerBar renders Model, Mode and Attach chips', (WidgetTester tester) async {
    String? selectedModel;
    ChatExecutionMode? selectedMode;

    await tester.binding.setSurfaceSize(const Size(400, 600));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: claudeTheme,
          home: Scaffold(
            body: ComposerBar(
              isGenerating: false,
              activePersonaName: 'Standard',
              selectedModel: 'llama3:latest',
              mode: ChatExecutionMode.optimal,
              onModelChanged: (m) => selectedModel = m,
              onModeChanged: (m) => selectedMode = m,
              onSend: (_) {},
              onStop: () {},
              onPersonaTap: () {},
            ),
          ),
        ),
      ),
    );

    // Verify chips render properly
    expect(find.text('llama3:latest'), findsOneWidget);
    expect(find.text(I18n.modeOptimal), findsOneWidget);
    expect(find.text(I18n.attach), findsOneWidget);
    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);

    // Open mode menu
    await tester.tap(find.text(I18n.modeOptimal));
    await tester.pumpAndSettle();

    // Verify modes are displayed
    expect(find.text(I18n.modeFast), findsOneWidget);
    expect(find.text(I18n.modeThinking), findsOneWidget);

    // Tap Schnell mode
    await tester.tap(find.text(I18n.modeFast));
    await tester.pumpAndSettle();
    expect(selectedMode, ChatExecutionMode.schnell);

    expect(selectedModel, isNull);

    // Reset surface size
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('ComposerBar renders active Workspace and AttachedFile pills with Git branch', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        workspaceProvider.overrideWith((ref) {
          final notifier = WorkspaceNotifier();
          notifier.state = const WorkspaceState(
            workspace: WorkspaceInfo(
              path: '/home/toms/git/tomsllama',
              name: 'tomsllama',
              gitBranch: 'exp',
              isGitRepo: true,
              files: ['lib/main.dart', 'pubspec.yaml'],
            ),
            attachedFiles: [
              AttachedFile(
                path: '/home/toms/git/tomsllama/lib/main.dart',
                name: 'main.dart',
                relativePath: 'lib/main.dart',
                sizeInBytes: 1024,
                estimatedTokens: 256,
                content: 'void main() {}',
                extension: '.dart',
              ),
            ],
          );
          return notifier;
        }),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: claudeTheme,
          home: Scaffold(
            body: ComposerBar(
              isGenerating: false,
              activePersonaName: 'Standard',
              onSend: (_) {},
              onStop: () {},
              onPersonaTap: () {},
            ),
          ),
        ),
      ),
    );

    // Verify workspace pill renders name and branch
    expect(find.text('tomsllama'), findsOneWidget);
    expect(find.text('exp'), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    expect(find.byIcon(Icons.call_split_rounded), findsOneWidget);

    // Verify attached file pill renders file name and token estimate
    expect(find.text('main.dart'), findsOneWidget);
    expect(find.text('256 tok'), findsOneWidget);

    // Verify remove button on file pill removes file
    final closeButtons = find.byIcon(Icons.close_rounded);
    expect(closeButtons, findsNWidgets(2)); // 1 for workspace, 1 for file

    await tester.tap(closeButtons.last);
    await tester.pumpAndSettle();

    expect(container.read(workspaceProvider).attachedFiles, isEmpty);
  });

  testWidgets('ComposerBar navigates prompt history with ArrowUp and ArrowDown', (WidgetTester tester) async {
    final sentPrompts = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: claudeTheme,
          home: Scaffold(
            body: ComposerBar(
              isGenerating: false,
              activePersonaName: 'Standard',
              onSend: (text) => sentPrompts.add(text),
              onStop: () {},
              onPersonaTap: () {},
            ),
          ),
        ),
      ),
    );

    final textField = find.byType(TextField);

    // 1. Send first prompt
    await tester.enterText(textField, 'First prompt');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(sentPrompts, ['First prompt']);

    // 2. Send second prompt
    await tester.enterText(textField, 'Second prompt');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(sentPrompts, ['First prompt', 'Second prompt']);

    // 3. User types a draft: "Current draft"
    await tester.enterText(textField, 'Current draft');
    await tester.pumpAndSettle();

    // 4. Press ArrowUp -> should load "Second prompt"
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(find.text('Second prompt'), findsOneWidget);

    // 5. Press ArrowUp again -> should load "First prompt"
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(find.text('First prompt'), findsOneWidget);

    // 6. Press ArrowDown -> should load "Second prompt"
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('Second prompt'), findsOneWidget);

    // 7. Press ArrowDown again -> should restore "Current draft"
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('Current draft'), findsOneWidget);
  });

  testWidgets('ComposerBar displays total summary next to pills when multiple files attached', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        workspaceProvider.overrideWith((ref) {
          final notifier = WorkspaceNotifier();
          notifier.state = const WorkspaceState(
            attachedFiles: [
              AttachedFile(
                path: '/home/toms/git/tomsllama/doc1.md',
                name: 'doc1.md',
                relativePath: 'doc1.md',
                sizeInBytes: 1024,
                estimatedTokens: 300,
                content: '# Doc 1',
                extension: '.md',
              ),
              AttachedFile(
                path: '/home/toms/git/tomsllama/doc2.md',
                name: 'doc2.md',
                relativePath: 'doc2.md',
                sizeInBytes: 2048,
                estimatedTokens: 600,
                content: '# Doc 2',
                extension: '.md',
              ),
            ],
          );
          return notifier;
        }),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: claudeTheme,
          home: Scaffold(
            body: ComposerBar(
              isGenerating: false,
              activePersonaName: 'Standard',
              onSend: (_) {},
              onStop: () {},
              onPersonaTap: () {},
            ),
          ),
        ),
      ),
    );

    // Verify both files are rendered with their token count but without individual speed/time
    expect(find.text('doc1.md'), findsOneWidget);
    expect(find.text('300 tok'), findsOneWidget);
    expect(find.text('doc2.md'), findsOneWidget);
    expect(find.text('600 tok'), findsOneWidget);

    // Verify summary pill is rendered next to them with total tokens (300+600=900 tok) and speed
    expect(find.textContaining('${I18n.totalLabel}: 900 tok'), findsOneWidget);
    expect(find.textContaining('tok/s'), findsOneWidget);
  });
}
