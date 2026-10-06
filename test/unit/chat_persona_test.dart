import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tomsllama/features/chat/controllers/chat_controller.dart';
import 'package:tomsllama/features/sidebar/controllers/sidebar_controller.dart';

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
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Persona is Standard by default, isolated per conversation, and persists on switch', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final chatNotifier = container.read(chatProvider.notifier);
    final sidebarNotifier = container.read(sidebarProvider.notifier);

    // Initial state must be 'Standard'
    expect(container.read(chatProvider).activePersonaName, 'Standard');

    // 1. Create first chat
    await chatNotifier.startNewChat();
    final chat1Id = container.read(chatProvider).conversationId!;
    expect(container.read(chatProvider).activePersonaName, 'Standard');

    // 2. Change persona of chat 1 to Marketing
    chatNotifier.setPersona('Marketing');
    expect(container.read(chatProvider).activePersonaName, 'Marketing');

    // Wait a tick for DB update
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Verify chat 1 has Marketing in sidebar state
    final conv1 = container.read(sidebarProvider).conversations.firstWhere((c) => c.id == chat1Id);
    expect(conv1.persona, 'Marketing');

    // 3. Start a brand new chat -> Must be 'Standard'
    // Send a message first or create directly
    final newConv = await sidebarNotifier.createNewConversation(title: 'Chat 2', persona: 'Standard');
    await chatNotifier.loadConversation(newConv.id);

    expect(container.read(chatProvider).conversationId, newConv.id);
    expect(container.read(chatProvider).activePersonaName, 'Standard');

    // 4. Switch back to chat 1 -> Must restore 'Marketing'
    await chatNotifier.loadConversation(chat1Id);
    expect(container.read(chatProvider).activePersonaName, 'Marketing');

    // 5. Switch back to chat 2 -> Must restore 'Standard'
    await chatNotifier.loadConversation(newConv.id);
    expect(container.read(chatProvider).activePersonaName, 'Standard');
  });
}
