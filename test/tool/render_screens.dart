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
import 'package:tomsllama/core/models/workspace.dart';
import 'package:tomsllama/core/models/workspace_context_file.dart';
import 'package:tomsllama/features/chat/widgets/composer_shelf.dart';
import 'package:tomsllama/core/widgets/cute_send_button.dart';
import 'package:tomsllama/features/chat/widgets/file_drop_overlay.dart';
import 'package:tomsllama/features/models/widgets/model_manager_dialog.dart';
import 'package:tomsllama/features/models/widgets/quick_switcher_modal.dart';
import 'package:tomsllama/features/settings/widgets/settings_dialog.dart';
import 'package:tomsllama/core/widgets/tomsllama_logo.dart';
import 'package:tomsllama/features/workspace/widgets/cute_llama_file_mascot.dart';
import 'package:tomsllama/features/workspace/widgets/new_workspace_dialog.dart';
import 'package:tomsllama/features/workspace/widgets/workspace_hub_view.dart';
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
        OllamaModel(name: 'qwen2.5:3b', model: 'qwen2.5:3b', size: 1, digest: 'a', modifiedAt: '', contextLength: 32768),
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

    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? p.dirname(p.dirname(Platform.resolvedExecutable));
    await _loadFont('MaterialIcons', [
      p.join(flutterRoot, 'bin', 'cache', 'artifacts', 'material_fonts', 'MaterialIcons-Regular.otf'),
    ]);
    await _loadFont('PhosphorLight', ['$fonts/PhosphorLight.ttf']);
    await _loadFont('Inter', ['$fonts/Inter-Regular.ttf', '$fonts/Inter-Medium.ttf', '$fonts/Inter-SemiBold.ttf']);
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
    // Containers are deliberately not disposed in this file: that would dispose
    // the app-wide calibration service they expose, which later scenes still use.

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

  // Popovers, the expanded shelf, the canvas and the waiting states, at the
  // smallest window size the app allows. Layout overflows fail this test.
  testWidgets('render interactions', (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(850, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(overrides: [
      chatProvider.overrideWith((ref) => _HarnessChat(ref)),
      modelProvider.overrideWith((ref) => _HarnessModels(ref)),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const TomsllamaApp()));
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await settle();
    await settle();
    await settle();
    Directory(outDir).createSync(recursive: true);
    Future<void> shot(String name) => expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(p.join(outDir, 'i_$name.png')),
        );

    final chat = container.read(chatProvider.notifier) as _HarnessChat;
    final convId = container.read(chatProvider).conversationId;
    final now = DateTime.now();
    Message msg(String id, String role, String content) =>
        Message(id: id, conversationId: convId ?? 'c', role: role, content: content, createdAt: now);

    await shot('small_empty');

    for (final chip in ['PersonaChip', '_ModelChip', '_ModeChip', '_AttachChip']) {
      final finder = find.byWidgetPredicate((w) => w.runtimeType.toString() == chip);
      expect(finder, findsOneWidget, reason: chip);
      await tester.tap(finder);
      await settle();
      await shot('menu_$chip');
      await tester.tapAt(const Offset(840, 300));
      await settle();
    }

    await tester.tap(find.byType(ShelfToggleButton));
    await settle();
    await shot('shelf');
    await tester.tap(find.byType(ShelfToggleButton));
    await settle();

    chat.show(ChatState(
      conversationId: convId,
      messages: [msg('u', 'user', 'Summarise the attached contract.'), msg('a', 'assistant', '')],
      isGenerating: true,
      statusMessage: 'Loading deepseek-r1:14b...',
      statusEtaSeconds: 24,
    ));
    await settle();
    await shot('status_loading');

    chat.show(ChatState(
      conversationId: convId,
      messages: [msg('u', 'user', 'Summarise the attached contract.'), msg('a', 'assistant', '')],
      isGenerating: true,
      statusMessage: 'Reading context...',
      statusTokens: 3200,
      statusEtaSeconds: 95,
    ));
    await settle();
    await shot('status_countdown');

    chat.show(ChatState(
      conversationId: convId,
      messages: [msg('u', 'user', 'Show me the code.'), msg('a', 'assistant', _answer.trim())],
      isCanvasOpen: true,
      canvasContent: 'int planCompaction(List<Message> history, int budget) {\n  return 0;\n}',
      canvasLanguage: 'dart',
    ));
    await settle();
    await shot('canvas');

    chat.show(ChatState(
      conversationId: convId,
      messages: [msg('u', 'user', 'Anyone there?')],
      errorMessage: 'Ollama is not reachable at http://localhost:11434. Is "ollama serve" running?',
    ));
    await settle();
    await shot('error');

    // A chat whose first exchange was folded into a summary, with the shelf open
    // on a window that is nearly full.
    final compacted = [
      msg('u1', 'user', 'How does the sliding window decide what to drop?'),
      msg('a1', 'assistant', 'It keeps the newest turns that fit the budget and drops the rest. ' * 12),
      msg('u2', 'user', 'And what happens to the dropped ones?'),
      msg('a2', 'assistant', 'They are folded into a short summary that is sent in their place.'),
    ];
    const summary = 'The user asked how the sliding window trims history. Newest turns are kept up to the '
        'budget; older ones are summarised.';
    chat.show(ChatState(
      conversationId: convId,
      messages: compacted,
      context: const ChatContextInfo(summary: summary, summaryThroughId: 'a1', tokens: 3300, window: 4096),
    ));
    await settle();
    await tester.tap(find.byType(ShelfToggleButton));
    await settle();
    await shot('context_shelf');
    await tester.tap(find.byType(ShelfToggleButton));
    await settle();

    await tester.ensureVisible(find.textContaining('→'));
    await tester.tap(find.textContaining('→'));
    await settle();
    await shot('summary_open');

    chat.show(ChatState(
      conversationId: convId,
      messages: compacted,
      compactingStatus: 'Summarising the conversation (2/3)...',
    ));
    await settle();
    await shot('compacting');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    debugDisableShadows = true;
  });

  // Screens that live outside the main chat layout, each rendered on its own.
  testWidgets('render secondary screens', (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final workspace = Workspace(
      id: 'ws_render',
      name: 'Erlebnisplaner',
      prompt: 'You are the principal engineer on this project. Answer briefly and in German.',
      createdAt: now,
      updatedAt: now,
    );
    final files = [
      WorkspaceContextFile(
        id: 'f1', workspaceId: 'ws_render', filePath: '/p/spec.md', fileName: 'spec.md',
        fileSize: 4200, content: '# Spec', estimatedTokens: 1240, createdAt: now,
      ),
      WorkspaceContextFile(
        id: 'f2', workspaceId: 'ws_render', filePath: '/p/vertrag.pdf', fileName: 'vertrag.pdf',
        fileSize: 88000, content: 'Vertrag', estimatedTokens: 610, createdAt: now,
      ),
    ];
    final chats = [
      for (final title in ['Datenbank-Schema planen', 'Rollen und Rechte', 'Release-Checkliste'])
        Conversation(id: title, title: title, createdAt: now, updatedAt: now, workspaceId: 'ws_render'),
    ];

    final scenes = <String, Widget>{
      'hub': WorkspaceHubView(
        workspace: workspace,
        files: files,
        chats: chats,
        onStartChat: (_, __, ___) {},
        onOpenChat: (_) {},
        onDeleteChat: (_) {},
      ),
      'settings': const Center(child: SettingsDialog()),
      'models': const Center(child: ModelManagerDialog()),
      'switcher': Center(child: QuickSwitcherModal(conversations: chats, onSelect: (_) {})),
      'new_workspace': const Center(child: NewWorkspaceDialog()),
      'drop': const FileDropOverlay(),
      'mascots': Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CuteLlamaFileMascot(size: 160.0),
            const SizedBox(width: 60.0),
            const TomsllamaLogo(size: 120.0),
            const SizedBox(width: 60.0),
            CuteSendButton(isGenerating: false, hasText: true, onTap: () {}),
            const SizedBox(width: 24.0),
            CuteSendButton(isGenerating: true, hasText: true, onTap: () {}),
          ],
        ),
      ),
    };

    // One container for all scenes: disposing it would dispose app-wide singletons it exposes.
    final container = ProviderContainer(overrides: [
      modelProvider.overrideWith((ref) => _HarnessModels(ref)),
    ]);

    Directory(outDir).createSync(recursive: true);
    for (final theme in [AppThemeType.claude, AppThemeType.dark]) {
      for (final scene in scenes.entries) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: getThemeData(theme),
              home: Scaffold(body: scene.value),
            ),
          ),
        );
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(p.join(outDir, 'x_${theme.name}_${scene.key}.png')),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      }
    }
    debugDisableShadows = true;
  });
}
