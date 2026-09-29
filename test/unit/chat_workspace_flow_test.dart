import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tomsllama/features/chat/controllers/workspace_controller.dart';

void main() {
  test('setWorkspace automatically loads code files into attachedFiles with full content', () async {
    final container = ProviderContainer();
    final notifier = container.read(workspaceProvider.notifier);

    final currentDir = Directory.current.path;
    await notifier.setWorkspace(currentDir);

    final state = container.read(workspaceProvider);

    // 1. Verify workspace is set
    expect(state.workspace, isNotNull);
    expect(state.workspace!.name, equals('tomsllama'));
    expect(state.workspace!.gitBranch, equals('exp'));

    // 2. Verify files are automatically attached with contents
    expect(state.attachedFiles, isNotEmpty);
    expect(state.totalAttachedTokens, greaterThan(0));

    final hasDartFiles = state.attachedFiles.any((f) => f.name.endsWith('.dart'));
    expect(hasDartFiles, isTrue);

    // Verify first file has real code
    final sampleFile = state.attachedFiles.first;
    expect(sampleFile.content, isNotEmpty);
    expect(sampleFile.toMarkdownBlock(), contains('```'));
  });
}
