import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tomsllama/core/models/conversation.dart';
import 'package:tomsllama/core/models/message.dart';
import 'package:tomsllama/core/services/database_service.dart';
import 'package:tomsllama/core/services/ollama_service.dart';
import 'package:tomsllama/features/chat/controllers/chat_controller.dart';
import 'package:tomsllama/features/models/controllers/model_controller.dart';
import 'package:tomsllama/features/sidebar/controllers/sidebar_controller.dart';

/// Minimal stand-in for the Ollama daemon: answers /api/chat with NDJSON chunks.
class _FakeOllama {
  late final HttpServer _server;
  final List<Map<String, dynamic>> chatRequests = [];
  final List<Map<String, dynamic>> summaryRequests = [];

  /// Reported as eval_count on the final chunk; 0 leaves the counters out.
  int evalCount = 0;
  List<Map<String, dynamic>> models = [];

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
    if (request.uri.path == '/api/ps') {
      request.response.write(jsonEncode({
        'models': [
          {'name': 'test-model'},
        ],
      }));
      await request.response.close();
      return;
    }
    if (request.uri.path == '/api/tags') {
      request.response.write(jsonEncode({'models': models}));
      await request.response.close();
      return;
    }

    final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
    final messages = (body['messages'] as List).cast<Map<String, dynamic>>();

    // Non-streaming requests are history summaries.
    if (body['stream'] == false) {
      summaryRequests.add(body);
      request.response.write(jsonEncode({
        'message': {'role': 'assistant', 'content': 'SUMMARY-OF-EARLIER-TURNS'},
        'done': true,
      }));
      await request.response.close();
      return;
    }

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
      response.write('${jsonEncode({
            'done': true,
            if (evalCount > 0 && !isTitleRequest) 'eval_count': evalCount,
            if (evalCount > 0 && !isTitleRequest) 'eval_duration': 2000000000,
          })}\n');
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
    ollama.summaryRequests.clear();
    ollama.evalCount = 0;
    ollama.models = [];
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

  test('exact counters from Ollama replace the streaming estimates', () async {
    final (container, chat) = await newChat();
    ollama.evalCount = 321;

    await chat.sendMessage('Count for me', 'test-model');
    await waitFor(() => !container.read(chatProvider).isGenerating);

    final answer = container.read(chatProvider).messages.last;
    expect(answer.tokens, 321);
    expect(answer.generationDurationMs, 2000);
    final saved = await stored(container.read(chatProvider).conversationId!);
    expect(saved.last.tokens, 321);
  });

  test('think is only sent to models that report the capability', () async {
    ollama.models = [
      {'name': 'thinker', 'capabilities': ['completion', 'thinking']},
      {'name': 'plain', 'capabilities': ['completion']},
    ];
    final (container, chat) = await newChat();
    await container.read(modelProvider.notifier).loadModels();

    chat.setMode(ChatExecutionMode.thinking);
    await chat.sendMessage('Reason about it', 'thinker');
    await waitFor(() => !container.read(chatProvider).isGenerating);
    expect(ollama.chatRequests.last['think'], isTrue);

    chat.setMode(ChatExecutionMode.schnell);
    await chat.sendMessage('Quick one', 'thinker');
    await waitFor(() => !container.read(chatProvider).isGenerating);
    expect(ollama.chatRequests.last['think'], isFalse);

    chat.setMode(ChatExecutionMode.thinking);
    await chat.sendMessage('Reason anyway', 'plain');
    await waitFor(() => !container.read(chatProvider).isGenerating);
    expect(ollama.chatRequests.last.containsKey('think'), isFalse);
  });

  test('old turns are folded into a summary that replaces them in the next prompt', () async {
    final (container, chat) = await newChat();
    // Two answers of 800 tokens outgrow the default-tier history budget.
    ollama.evalCount = 800;

    await chat.sendMessage('First question', 'test-model');
    await waitFor(() => !container.read(chatProvider).isGenerating);
    expect(ollama.summaryRequests, isEmpty);

    await chat.sendMessage('Second question', 'test-model');
    await waitFor(() => !container.read(chatProvider).isGenerating);
    await waitFor(() => ollama.summaryRequests.isNotEmpty);

    final convId = container.read(chatProvider).conversationId!;
    Conversation? conv;
    for (var i = 0; i < 100; i++) {
      conv = await DatabaseService().getConversation(convId);
      if (conv?.summary != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(conv!.summary, 'SUMMARY-OF-EARLIER-TURNS');
    final summaryPrompt = (ollama.summaryRequests.single['messages'] as List).single['content'] as String;
    expect(summaryPrompt, contains('First question'));
    expect(summaryPrompt, isNot(contains('Second question')));

    await chat.sendMessage('Third question', 'test-model');
    await waitFor(() => !container.read(chatProvider).isGenerating);

    final sent = (ollama.chatRequests.last['messages'] as List).cast<Map<String, dynamic>>();
    expect(sent.first['role'], 'system');
    expect(sent.first['content'], contains('SUMMARY-OF-EARLIER-TURNS'));
    final userTurns = sent.where((m) => m['role'] == 'user').map((m) => m['content']).toList();
    expect(userTurns, ['Second question', 'Third question']);
    // Everything on screen is still there; only the prompt was compacted.
    expect(container.read(chatProvider).messages.where((m) => m.role == 'user'), hasLength(3));
  });

  test('an answer keeps generating in the background when another chat is opened', () async {
    final (container, chat) = await newChat();
    final sidebar = container.read(sidebarProvider.notifier);
    ollama.reply = ['Part one', ', part two'];
    ollama.holdAfterFirstChunk = Completer<void>();

    await chat.sendMessage('Long running question', 'test-model');
    final firstId = container.read(chatProvider).conversationId!;
    await waitFor(() => container.read(chatProvider).messages.last.content == 'Part one');

    // Open a different chat while the first one is still streaming.
    final other = await sidebar.createNewConversation(title: 'Other chat');
    await chat.loadConversation(other.id);
    var state = container.read(chatProvider);
    expect(state.conversationId, other.id);
    expect(state.isGenerating, isFalse);
    expect(state.messages, isEmpty);
    expect(state.generatingConversationIds, {firstId});

    // The rest of the answer arrives while the other chat is on screen.
    ollama.holdAfterFirstChunk!.complete();
    await waitFor(() => container.read(chatProvider).generatingConversationIds.isEmpty);
    expect(container.read(chatProvider).messages, isEmpty);
    expect((await stored(firstId)).map((m) => m.content), ['Long running question', 'Part one, part two']);

    // Coming back shows the finished answer.
    await chat.loadConversation(firstId);
    state = container.read(chatProvider);
    expect(state.isGenerating, isFalse);
    expect(state.messages.map((m) => m.content), ['Long running question', 'Part one, part two']);
  });

  test('returning to a chat that is still generating resumes the live stream', () async {
    final (container, chat) = await newChat();
    final sidebar = container.read(sidebarProvider.notifier);
    ollama.reply = ['Still', ' going'];
    ollama.holdAfterFirstChunk = Completer<void>();

    await chat.sendMessage('Another long question', 'test-model');
    final firstId = container.read(chatProvider).conversationId!;
    await waitFor(() => container.read(chatProvider).messages.last.content == 'Still');

    final other = await sidebar.createNewConversation(title: 'Detour');
    await chat.loadConversation(other.id);
    await chat.loadConversation(firstId);

    var state = container.read(chatProvider);
    expect(state.isGenerating, isTrue);
    expect(state.messages.map((m) => m.content), ['Another long question', 'Still']);

    ollama.holdAfterFirstChunk!.complete();
    await waitFor(() => !container.read(chatProvider).isGenerating);
    state = container.read(chatProvider);
    expect(state.messages.last.content, 'Still going');

    // Stop only ever applies to the chat on screen.
    expect(state.generatingConversationIds, isEmpty);
  });

  test('stop in one chat does not touch an answer running in another', () async {
    final (container, chat) = await newChat();
    final sidebar = container.read(sidebarProvider.notifier);
    ollama.reply = ['Background', ' answer'];
    ollama.holdAfterFirstChunk = Completer<void>();

    await chat.sendMessage('Keep going', 'test-model');
    final firstId = container.read(chatProvider).conversationId!;
    await waitFor(() => container.read(chatProvider).messages.last.content == 'Background');

    final other = await sidebar.createNewConversation(title: 'Foreground');
    await chat.loadConversation(other.id);
    chat.stopGeneration();
    expect(container.read(chatProvider).generatingConversationIds, {firstId});

    ollama.holdAfterFirstChunk!.complete();
    await waitFor(() => container.read(chatProvider).generatingConversationIds.isEmpty);
    expect((await stored(firstId)).last.content, 'Background answer');
  });

  test('deleting a chat discards its running answer', () async {
    final (container, chat) = await newChat();
    final sidebar = container.read(sidebarProvider.notifier);
    ollama.reply = ['Doomed', ' text'];
    ollama.holdAfterFirstChunk = Completer<void>();

    await chat.sendMessage('Soon deleted', 'test-model');
    final firstId = container.read(chatProvider).conversationId!;
    await waitFor(() => container.read(chatProvider).messages.last.content == 'Doomed');

    chat.discardGeneration(firstId);
    await sidebar.deleteConversation(firstId);
    expect(container.read(chatProvider).generatingConversationIds, isEmpty);
    expect(container.read(chatProvider).isGenerating, isFalse);
    expect(await stored(firstId), isEmpty);

    ollama.holdAfterFirstChunk!.complete();
  });

  test('stripAttachmentPrefix returns the typed text', () {
    expect(ChatNotifier.stripAttachmentPrefix('[attached:a.dart, b.md]\nExplain this'), 'Explain this');
    expect(ChatNotifier.stripAttachmentPrefix('[attached:a.dart]'), '');
    expect(ChatNotifier.stripAttachmentPrefix('No files here'), 'No files here');
  });
}
