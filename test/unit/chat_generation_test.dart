import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tomsllama/core/models/message.dart';
import 'package:tomsllama/core/services/database_service.dart';
import 'package:tomsllama/core/services/ollama_service.dart';
import 'package:tomsllama/features/chat/controllers/chat_controller.dart';

/// Minimal stand-in for the Ollama daemon: answers /api/chat with NDJSON chunks.
class _FakeOllama {
  late final HttpServer _server;
  final List<Map<String, dynamic>> chatRequests = [];

  List<String> reply = ['Hello', ' world'];

  /// When set, the stream pauses after the first chunk until this completes.
  Completer<void>? holdAfterFirstChunk;

  String get url => 'http://${_server.address.address}:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
    final messages = (body['messages'] as List).cast<Map<String, dynamic>>();
    final isTitleRequest = (messages.first['content'] as String).startsWith('Summarize the user');
    if (!isTitleRequest) chatRequests.add(body);

    final response = request.response;
    response.bufferOutput = false;
    response.headers.contentType = ContentType('application', 'x-ndjson');

    final chunks = isTitleRequest ? ['Title'] : reply;
    try {
      for (var i = 0; i < chunks.length; i++) {
        response.write('${jsonEncode({
              'message': {'role': 'assistant', 'content': chunks[i]},
              'done': false,
            })}\n');
        await response.flush();
        if (i == 0 && !isTitleRequest && holdAfterFirstChunk != null) {
          await holdAfterFirstChunk!.future;
        }
      }
      response.write('${jsonEncode({'done': true})}\n');
      await response.close();
    } catch (_) {
      // Client cancelled the stream.
    }
  }
}

void main() {
  final ollama = _FakeOllama();
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The test binding answers every HTTP request with 400; these tests talk to a loopback server.
    HttpOverrides.global = null;
    tempDir = await Directory.systemTemp.createTemp('tomsllama_chat_test');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async => tempDir.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await ollama.start();
  });

  tearDownAll(() async {
    await ollama.stop();
  });

  setUp(() {
    OllamaService().baseUrl = ollama.url;
    ollama.chatRequests.clear();
    ollama.reply = ['Hello', ' world'];
    ollama.holdAfterFirstChunk = null;
  });

  Future<void> waitFor(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for condition');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<List<Message>> stored(String conversationId) =>
      DatabaseService().getMessagesForConversation(conversationId);

  /// Each test gets its own conversation; the notifier reuses an empty one otherwise.
  Future<(ProviderContainer, ChatNotifier)> newChat() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier);
    return (container, notifier);
  }

  test('a completed answer is streamed into state and persisted', () async {
    final (container, chat) = await newChat();

    await chat.sendMessage('Hi there', 'test-model');
    await waitFor(() => !container.read(chatProvider).isGenerating);

    final state = container.read(chatProvider);
    expect(state.errorMessage, isNull);
    expect(state.messages.map((m) => m.role), ['user', 'assistant']);
    expect(state.messages.last.content, 'Hello world');

    final saved = await stored(state.conversationId!);
    expect(saved.map((m) => m.content), ['Hi there', 'Hello world']);
  });

  test('stopping mid-stream keeps and persists the partial answer', () async {
    final (container, chat) = await newChat();
    ollama.reply = ['Partial', ' never sent'];
    ollama.holdAfterFirstChunk = Completer<void>();

    await chat.sendMessage('Tell me something long', 'test-model');
    await waitFor(() => container.read(chatProvider).messages.last.content == 'Partial');

    chat.stopGeneration();
    final state = container.read(chatProvider);
    expect(state.isGenerating, isFalse);
    expect(state.messages.last.content, 'Partial');

    // The save is fire-and-forget from a synchronous stop; give it a moment.
    var saved = await stored(state.conversationId!);
    for (var i = 0; i < 100 && saved.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      saved = await stored(state.conversationId!);
    }
    expect(saved.map((m) => m.content), ['Tell me something long', 'Partial']);

    ollama.holdAfterFirstChunk!.complete();
  });

  test('stopping before any output removes the empty placeholder', () async {
    final (container, chat) = await newChat();
    ollama.reply = ['', 'late'];
    ollama.holdAfterFirstChunk = Completer<void>();

    await chat.sendMessage('Question', 'test-model');
    await waitFor(() => ollama.chatRequests.isNotEmpty);

    chat.stopGeneration();
    final state = container.read(chatProvider);
    expect(state.isGenerating, isFalse);
    expect(state.messages.map((m) => m.role), ['user']);

    ollama.holdAfterFirstChunk!.complete();
  });

  test('regenerate replaces the answer without sending the user turn twice', () async {
    final (container, chat) = await newChat();

    await chat.sendMessage('What is 2+2?', 'test-model');
    await waitFor(() => !container.read(chatProvider).isGenerating);

    ollama.chatRequests.clear();
    ollama.reply = ['Second', ' answer'];
    await chat.regenerateLast('test-model');
    await waitFor(() => !container.read(chatProvider).isGenerating);

    final state = container.read(chatProvider);
    expect(state.messages.map((m) => m.content), ['What is 2+2?', 'Second answer']);

    final saved = await stored(state.conversationId!);
    expect(saved.map((m) => m.content), ['What is 2+2?', 'Second answer']);

    final sent = (ollama.chatRequests.single['messages'] as List).cast<Map<String, dynamic>>();
    final userTurns = sent.where((m) => m['role'] == 'user').toList();
    expect(userTurns, hasLength(1));
    expect(userTurns.single['content'], 'What is 2+2?');
    expect(sent.any((m) => m['role'] == 'assistant'), isFalse);
  });

  test('an unreachable daemon surfaces an error instead of an empty reply', () async {
    final (container, chat) = await newChat();
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final deadUrl = 'http://127.0.0.1:${closed.port}';
    await closed.close();
    OllamaService().baseUrl = deadUrl;

    await chat.sendMessage('Anyone home?', 'test-model');
    await waitFor(() => !container.read(chatProvider).isGenerating);

    final state = container.read(chatProvider);
    expect(state.errorMessage, contains(deadUrl));
    expect(state.messages.map((m) => m.role), ['user']);
  });

  test('stripAttachmentPrefix returns the typed text', () {
    expect(ChatNotifier.stripAttachmentPrefix('[attached:a.dart, b.md]\nExplain this'), 'Explain this');
    expect(ChatNotifier.stripAttachmentPrefix('[attached:a.dart]'), '');
    expect(ChatNotifier.stripAttachmentPrefix('No files here'), 'No files here');
  });
}
