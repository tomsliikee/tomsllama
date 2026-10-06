// Renders the main chat screen to PNG files so a design change can be looked at
// without launching the desktop app. Not part of the test suite (no _test suffix).
//
//   RENDER_OUT=/some/dir flutter test --update-goldens test/tool/render_screens.dart
//
// Output defaults to build/renders/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tomsllama/core/models/conversation.dart';
import 'package:tomsllama/core/models/message.dart';
import 'package:tomsllama/core/models/ollama_model.dart';
import 'package:tomsllama/core/services/database_service.dart';
import 'package:tomsllama/core/theme/app_theme.dart';
import 'package:tomsllama/features/chat/controllers/chat_controller.dart';
import 'package:tomsllama/features/models/controllers/model_controller.dart';
import 'package:tomsllama/main.dart';

class _HarnessChat extends ChatNotifier {
  _HarnessChat(super.ref);

  void show(ChatState next) => state = next;
}

class _HarnessModels extends ModelNotifier {
  _HarnessModels(super.ref);

  @override
  Future<void> loadModels() async {
    state = const ModelState(
      models: [
        OllamaModel(name: 'qwen2.5:3b', model: 'qwen2.5:3b', size: 1, digest: 'a', modifiedAt: ''),
        OllamaModel(name: 'deepseek-r1:14b', model: 'deepseek-r1:14b', size: 1, digest: 'b', modifiedAt: ''),
      ],
      selectedModel: 'qwen2.5:3b',
    );
  }
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

const _answer = '''
## Sliding window, in short

A model only sees what fits in its **context window**. When a chat grows past it, the oldest turns have to go. There are two ways to do that:

1. Drop a little every turn, which keeps the most text but changes the prompt each time.
2. Drop a larger piece now and then, and keep a *summary* of what was removed.

The second keeps the prompt prefix stable, so `prompt_eval` stays cheap between cuts.

```dart
int planCompaction(List<Message> history, int budget) {
  final total = history.fold<int>(0, (sum, m) => sum + m.tokens);
  if (total <= budget * 3 ~/ 4) return 0;
  return history.length - 2;
}
```

Ask if you want the trade-offs for thinking models.
''';

void main() {
  final outDir = Platform.environment['RENDER_OUT'] ?? p.join(Directory.current.path, 'build', 'renders');
  late Directory dataDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dataDir = await Directory.systemTemp.createTemp('tomsllama_render');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => dataDir.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    const fonts = 'assets/fonts';
    await _loadFont('Newsreader', ['$fonts/Newsreader-Regular.ttf', '$fonts/Newsreader-Italic.ttf', '$fonts/Newsreader-SemiBold.ttf']);
    await _loadFont('GeistMono', ['$fonts/GeistMono-Regular.ttf', '$fonts/GeistMono-Medium.ttf', '$fonts/GeistMono-SemiBold.ttf']);
    await _loadFont('Inter', ['$fonts/Inter-Regular.ttf', '$fonts/Inter-Medium.ttf', '$fonts/Inter-SemiBold.ttf']);

    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? p.dirname(p.dirname(Platform.resolvedExecutable));
    await _loadFont('MaterialIcons', [
      p.join(flutterRoot, 'bin', 'cache', 'artifacts', 'material_fonts', 'MaterialIcons-Regular.otf'),
    ]);
    await _loadFont('PhosphorLight', ['$fonts/PhosphorLight.ttf']);
  });

  testWidgets('render chat screen', (tester) async {
    // Tests paint shadows as solid blocks unless told otherwise.
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    const activeId = 'conv_active';
    await tester.runAsync(() async {
      final db = DatabaseService();
      final titles = [
        'Sliding window explained',
        'Rust lifetimes in practice',
        'Brief an die Hausverwaltung',
        'SQLite migration plan',
        'Weekend trip to Graz',
      ];
      for (var i = 0; i < titles.length; i++) {
        await db.saveConversation(Conversation(
          id: i == 0 ? activeId : 'conv_$i',
          title: titles[i],
          createdAt: now.subtract(Duration(hours: i)),
          updatedAt: now.subtract(Duration(hours: i)),
          isPinned: i == 1,
        ));
        await db.saveMessage(Message(
          id: 'seed_$i',
          conversationId: i == 0 ? activeId : 'conv_$i',
          role: 'user',
          content: 'seed',
          createdAt: now,
        ));
      }
    });

    final container = ProviderContainer(overrides: [
      chatProvider.overrideWith((ref) => _HarnessChat(ref)),
      modelProvider.overrideWith((ref) => _HarnessModels(ref)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const TomsllamaApp()));
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      // Several frames, so chained implicit animations (theme, containers) all finish.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    // The shell loads conversations and opens a chat after its first frame.
    await settle();
    await settle();
    await settle();
    final chat = container.read(chatProvider.notifier) as _HarnessChat;
    final emptyState = container.read(chatProvider);

    final user = Message(
      id: 'u1',
      conversationId: activeId,
      role: 'user',
      content: '[attached:context_manager.dart]\nHow does the sliding window decide what to drop, and why does it matter for speed?',
      createdAt: now,
    );
    final assistant = Message(
      id: 'a1',
      conversationId: activeId,
      role: 'assistant',
      content: _answer.trim(),
      thinkContent: 'The user asks about the trimming strategy. Explain the budget first, then the two strategies, then the cache effect.',
      createdAt: now,
      tokens: 412,
      generationDurationMs: 31200,
    );

    final scenes = <String, ChatState>{
      'empty': emptyState,
      'conversation': ChatState(conversationId: activeId, messages: [user, assistant]),
      'streaming': ChatState(
        conversationId: activeId,
        messages: [
          user,
          assistant.copyWith(content: _answer.trim().substring(0, 260), tokens: 64, generationDurationMs: 5200),
        ],
        isGenerating: true,
        generatingConversationIds: const {activeId},
      ),
    };

    Directory(outDir).createSync(recursive: true);
    for (final theme in AppThemeType.values) {
      container.read(themeProvider.notifier).setTheme(theme);
      for (final scene in scenes.entries) {
        chat.show(scene.value);
        await settle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(p.join(outDir, '${theme.name}_${scene.key}.png')),
        );
      }
    }

    // Unmount so periodic timers in the logo and indicators are cancelled.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    debugDisableShadows = true;
  });
}
