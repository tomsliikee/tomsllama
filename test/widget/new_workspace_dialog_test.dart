import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/services/localization_service.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/features/workspace/widgets/new_workspace_dialog.dart';

void main() {
  testWidgets('NewWorkspaceDialog renders and returns name and prompt on submit', (WidgetTester tester) async {
    Map<String, String>? returnedResult;

    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              returnedResult = await showDialog<Map<String, String>>(
                context: context,
                builder: (_) => const NewWorkspaceDialog(),
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text(I18n.newWorkspaceTitle), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    // Enter name
    await tester.enterText(find.byType(TextField).first, 'Erlebnisplaner');
    // Enter prompt
    await tester.enterText(find.byType(TextField).last, 'Du bist der Lead Architect.');

    // Tap create
    await tester.tap(find.text(I18n.create));
    await tester.pumpAndSettle();

    expect(returnedResult, isNotNull);
    expect(returnedResult!['name'], 'Erlebnisplaner');
    expect(returnedResult!['prompt'], 'Du bist der Lead Architect.');
  });
}
