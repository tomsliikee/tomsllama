// Manual check against a running Ollama: how close is the reply estimate to reality?
//   flutter test test/tool/live_estimate_check.dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tomsllama/core/services/context_manager.dart';
import 'package:tomsllama/core/services/hardware_calibration_service.dart';
import 'package:tomsllama/features/chat/controllers/chat_controller.dart';
import 'package:tomsllama/features/models/controllers/model_controller.dart';

void main() {
  const model = String.fromEnvironment('MODEL', defaultValue: 'qwen2.5:3b');

  test('estimate vs. measured reply time', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    final dir = await Directory.systemTemp.createTemp('tomsllama_live');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => dir.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(modelProvider.notifier).loadModels();
    final chat = container.read(chatProvider.notifier);
    final hw = HardwareCalibrationService();

    Future<double> ask(String text) async {
      final watch = Stopwatch()..start();
      await chat.sendMessage(text, model);
      while (container.read(chatProvider).isGenerating) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final err = container.read(chatProvider).errorMessage;
      if (err != null) fail(err);
      return watch.elapsedMilliseconds / 1000.0;
    }

    const questions = [
      'Explain what a hash map is in about 100 words.',
      'Explain what a binary search tree is in about 100 words.',
      'Explain what a bloom filter is in about 100 words.',
      'And when would I pick it over a hash set? About 100 words.',
      'Give one concrete example of that in practice, about 100 words.',
    ];

    for (var i = 0; i < questions.length; i++) {
      // Questions 0-2 each open a new chat (nothing cached); 3 and 4 follow up in the last one.
      if (i <= 2) await chat.startNewChat();
      final state = container.read(chatProvider);
      final lastAnswer = state.messages.where((m) => m.role == 'assistant').lastOrNull;
      final userTokens = ContextManager.estimateTokens(questions[i]);
      final uncached = i <= 2 ? userTokens + 40 : userTokens + (lastAnswer == null ? 0 : ContextManager.historyTokens(lastAnswer));
      final estimate = hw.estimateResponse(uncachedPromptTokens: uncached, modelName: model);
      final actual = await ask(questions[i]);
      final answer = container.read(chatProvider).messages.last;
      // ignore: avoid_print
      print('q$i  estimate=${estimate.isTested ? '${estimate.totalSeconds}s' : 'untested'}  actual=${actual.toStringAsFixed(1)}s  '
          'answer=${answer.tokens} tok  profile=${hw.modelProfiles[model]?.toJson()}');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
