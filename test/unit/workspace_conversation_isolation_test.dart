import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tomsllama/features/chat/controllers/workspace_controller.dart';

void main() {
  test('WorkspaceNotifier isolates attached files and workspaces per conversation', () async {
    final container = ProviderContainer();
    final notifier = container.read(workspaceProvider.notifier);

    // 1. In Conversation 1, attach a file
    notifier.setActiveConversation('conv_1');
    final dummyFile = File('pubspec.yaml').absolute.path;
    await notifier.attachFiles([dummyFile]);

    var state1 = container.read(workspaceProvider);
    expect(state1.attachedFiles, isNotEmpty);
    expect(state1.attachedFiles.first.name, equals('pubspec.yaml'));

    // 2. Switch to Conversation 2 (empty state)
    notifier.setActiveConversation('conv_2');
    var state2 = container.read(workspaceProvider);
    expect(state2.attachedFiles, isEmpty);
    expect(state2.workspace, isNull);

    // In Conversation 2, attach a workspace
    final currentDir = Directory.current.path;
    await notifier.setWorkspace(currentDir, autoAttachFiles: false);
    state2 = container.read(workspaceProvider);
    expect(state2.workspace, isNotNull);

    // 3. Switch back to Conversation 1
    notifier.setActiveConversation('conv_1');
    state1 = container.read(workspaceProvider);
    // Preserves original attachment in conv_1 without conv_2's workspace!
    expect(state1.attachedFiles, isNotEmpty);
    expect(state1.attachedFiles.first.name, equals('pubspec.yaml'));
    expect(state1.workspace, isNull);

    // 4. Remove Conversation 1
    notifier.removeConversation('conv_1');
    state1 = container.read(workspaceProvider);
    expect(state1.attachedFiles, isEmpty);
  });
}
