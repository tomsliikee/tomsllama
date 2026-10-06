import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tomsllama/features/workspace/controllers/workspace_hub_controller.dart';

// Each test file gets its own documents directory, and with it its own database.
final String _documentsDir = Directory.systemTemp.createTempSync('tomsllama_test').path;

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return _documentsDir;
    });
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  test('WorkspaceHubController manages list, creation, active selection, and prompt', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final listNotifier = container.read(workspaceListProvider.notifier);
    await listNotifier.loadWorkspaces();

    // 1. Create Workspace
    final ws = await listNotifier.createNewWorkspace(
      name: 'Mobile Core',
      prompt: 'System prompt initial',
    );
    expect(ws.name, 'Mobile Core');
    expect(container.read(workspaceListProvider).workspaces.any((w) => w.id == ws.id), isTrue);

    // 2. Active workspace state
    final activeNotifier = container.read(activeWorkspaceProvider.notifier);
    await activeNotifier.loadWorkspace(ws.id);
    expect(container.read(activeWorkspaceProvider).workspace?.name, 'Mobile Core');

    // 3. Update prompt
    await activeNotifier.updatePrompt('Updated Workspace Prompt');
    expect(container.read(activeWorkspaceProvider).workspace?.prompt, 'Updated Workspace Prompt');

    // 4. Pin workspace
    await listNotifier.togglePin(ws.id);
    final pinned = container.read(workspaceListProvider).workspaces.firstWhere((w) => w.id == ws.id);
    expect(pinned.isPinned, isTrue);

    // 5. Delete workspace
    await listNotifier.deleteWorkspace(ws.id);
    expect(container.read(workspaceListProvider).workspaces.any((w) => w.id == ws.id), isFalse);
  });
}
