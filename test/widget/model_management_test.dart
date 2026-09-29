import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/core/models/ollama_model.dart';
import 'package:tomsllama/core/services/localization_service.dart';
import 'package:tomsllama/features/models/widgets/model_selector_dropdown.dart';

void main() {
  testWidgets('ModelSelectorDropdown shows models and manage option', (WidgetTester tester) async {
    const models = [
      OllamaModel(name: 'qwen2.5-coder:1.5b', model: 'qwen', size: 1000, digest: '123', modifiedAt: 'now'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: Scaffold(
          body: ModelSelectorDropdown(
            models: models,
            selectedModel: 'qwen2.5-coder:1.5b',
            onChanged: (String? value) {},
            onManageModels: () {},
          ),
        ),
      ),
    );

    expect(find.text('qwen2.5-coder:1.5b'), findsOneWidget);
    
    // Open dropdown
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    expect(find.text(I18n.manageModels), findsOneWidget);
  });
}
