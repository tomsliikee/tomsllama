import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tomsllama/core/models/conversation.dart';
import 'package:tomsllama/core/models/workspace.dart';
import 'package:tomsllama/core/models/workspace_context_file.dart';
import 'package:tomsllama/core/services/database_service.dart';

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

  test('DatabaseService supports Workspace and WorkspaceContextFiles operations', () async {
    final dbService = DatabaseService();
    final now = DateTime.now();

    // 1. Create Workspace
    final ws = Workspace(
      id: 'ws_test_1',
      name: 'Erlebnisplaner Test',
      prompt: 'Du bist System-Architekt.',
      createdAt: now,
      updatedAt: now,
    );
    await dbService.saveWorkspace(ws);

    final loadedWs = await dbService.getWorkspace('ws_test_1');
    expect(loadedWs, isNotNull);
    expect(loadedWs!.name, equals('Erlebnisplaner Test'));
    expect(loadedWs.prompt, equals('Du bist System-Architekt.'));
    expect(loadedWs.isPinned, isFalse);

    // 2. Update prompt & pin
    await dbService.updateWorkspacePrompt('ws_test_1', 'Neuer Prompt');
    await dbService.togglePinWorkspace('ws_test_1');

    final updatedWs = await dbService.getWorkspace('ws_test_1');
    expect(updatedWs!.prompt, equals('Neuer Prompt'));
    expect(updatedWs.isPinned, isTrue);

    // 3. Add context file to workspace
    final ctxFile = WorkspaceContextFile(
      id: 'file_1',
      workspaceId: 'ws_test_1',
      filePath: '/dummy/spec.md',
      fileName: 'spec.md',
      fileSize: 1024,
      content: '# Spec\nArchitecture details.',
      estimatedTokens: 25,
      createdAt: now,
    );
    await dbService.addWorkspaceFile(ctxFile);

    final files = await dbService.getWorkspaceFiles('ws_test_1');
    expect(files.length, equals(1));
    expect(files.first.fileName, equals('spec.md'));
    expect(files.first.estimatedTokens, equals(25));

    // 4. Attach conversation to workspace
    final conv = Conversation(
      id: 'conv_in_ws_1',
      title: 'Workspace Chat 1',
      createdAt: now,
      updatedAt: now,
      workspaceId: 'ws_test_1',
      isWorkspaceContextEnabled: true,
    );
    await dbService.saveConversation(conv);

    final wsConvs = await dbService.getConversationsForWorkspace('ws_test_1');
    expect(wsConvs.length, equals(1));
    expect(wsConvs.first.id, equals('conv_in_ws_1'));
    expect(wsConvs.first.isWorkspaceContextEnabled, isTrue);

    // 5. Toggle context for conversation
    await dbService.toggleWorkspaceContextForConversation('conv_in_ws_1', false);
    final toggledConvs = await dbService.getConversationsForWorkspace('ws_test_1');
    expect(toggledConvs.first.isWorkspaceContextEnabled, isFalse);

    // 6. Delete workspace and verify cascading cleanup
    await dbService.deleteWorkspace('ws_test_1');
    expect(await dbService.getWorkspace('ws_test_1'), isNull);
    expect((await dbService.getWorkspaceFiles('ws_test_1')).isEmpty, isTrue);
    expect((await dbService.getConversationsForWorkspace('ws_test_1')).isEmpty, isTrue);
  });
}
