// Manual check against a running Ollama: context usage and /compact end to end.
//   flutter test test/tool/live_compact_check.dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tomsllama/features/chat/controllers/chat_controller.dart';
import 'package:tomsllama/features/models/controllers/model_controller.dart';

void main() {
  const model = String.fromEnvironment('MODEL', defaultValue: 'qwen2.5:3b');

  test('usage is measured and /compact carries the thread', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    final dir = await Directory.systemTemp.createTemp('tomsllama_live_compact');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => dir.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final container = ProviderContainer();
    await container.read(modelProvider.notifier).loadModels();
    final chat = container.read(chatProvider.notifier);
    ChatState state() => container.read(chatProvider);

    Future<void> ask(String text) async {
      await chat.sendMessage(text, model);
      while (state().isGenerating) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (state().errorMessage != null) fail(state().errorMessage!);
      // The usage is written just after the answer is finalised.
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }

    void report(String label) {
      final c = state().context;
      // ignore: avoid_print
      print('$label: ${c.tokens} / ${c.window} tokens${c.isEstimate ? ' (estimate)' : ''}');
    }

    final maxContext = container.read(modelProvider).models.where((m) => m.name == model).firstOrNull?.contextLength;
    // ignore: avoid_print
    print('$model reports a maximum context of $maxContext');

    await chat.startNewChat();
    await ask('My dog is called Biscuit and he is 7 years old. Tell me two facts about beagles, about 80 words.');
    report('after turn 1');
    await ask('Now two facts about greyhounds, about 80 words.');
    report('after turn 2');
    final before = state().context.tokens!;

    final watch = Stopwatch()..start();
    await chat.sendMessage('/compact keep the name and age of my dog', model);
    // ignore: avoid_print
    print('compact took ${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s\nSUMMARY: ${state().context.summary}');
    report('after /compact');
    expect(state().context.summary, isNotNull);

    await ask('What is my dog called and how old is he? One short sentence.');
    report('after turn 3');
    // ignore: avoid_print
    print('ANSWER: ${state().messages.last.content}');
    expect(state().messages.last.content, contains('Biscuit'));
    expect(state().context.tokens!, lessThan(before));
  }, timeout: const Timeout(Duration(minutes: 15)));
}
