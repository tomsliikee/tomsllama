import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/message.dart';
import '../../../../core/models/persona.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/ollama_service.dart';
import '../../../../core/services/title_service.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/services/context_manager.dart';
import 'package:path/path.dart' as p;
import '../../../../core/utils/think_parser.dart';
import '../../../../core/models/attached_file.dart';
import '../../../../core/models/workspace_info.dart';
import '../../../../core/services/repo_map_service.dart';
import '../../../../core/services/workspace_search_service.dart';
import '../../sidebar/controllers/sidebar_controller.dart';
import 'workspace_controller.dart';

class ChatState {
  final String? conversationId;
  final List<Message> messages;
  final bool isGenerating;
  final String activePersonaName;
  final double temperature;
  final bool isCanvasOpen;
  final String? canvasContent;
  final String? canvasLanguage;
  final String? errorMessage;
  final String? statusMessage;

  const ChatState({
    this.conversationId,
    this.messages = const [],
    this.isGenerating = false,
    this.activePersonaName = 'Standard',
    this.temperature = 0.7,
    this.isCanvasOpen = false,
    this.canvasContent,
    this.canvasLanguage,
    this.errorMessage,
    this.statusMessage,
  });

  ChatState copyWith({
    String? conversationId,
    List<Message>? messages,
    bool? isGenerating,
    String? activePersonaName,
    double? temperature,
    bool? isCanvasOpen,
    String? canvasContent,
    String? canvasLanguage,
    String? errorMessage,
    String? statusMessage,
    bool clearCanvas = false,
    bool clearStatusMessage = false,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      activePersonaName: activePersonaName ?? this.activePersonaName,
      temperature: temperature ?? this.temperature,
      isCanvasOpen: isCanvasOpen ?? this.isCanvasOpen,
      canvasContent: clearCanvas ? null : (canvasContent ?? this.canvasContent),
      canvasLanguage: clearCanvas ? null : (canvasLanguage ?? this.canvasLanguage),
      errorMessage: errorMessage,
      statusMessage: clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final DatabaseService _db = DatabaseService();
  final OllamaService _ollama = OllamaService();
  final Ref _ref;
  StreamSubscription<String>? _activeStream;

  ChatNotifier(this._ref) : super(const ChatState());

  Future<void> loadConversation(String conversationId) async {
    _activeStream?.cancel();

    _ref.read(workspaceProvider.notifier).setActiveConversation(conversationId);

    // Retrieve the persona saved specifically for this conversation
    final allConvs = await _db.getConversations();
    final conv = allConvs.where((c) => c.id == conversationId).firstOrNull;
    final persona = conv?.persona ?? 'Standard';

    state = state.copyWith(
      conversationId: conversationId,
      activePersonaName: persona,
      isGenerating: false,
      errorMessage: null,
      clearCanvas: true,
      isCanvasOpen: false,
    );
    final msgs = await _db.getMessagesForConversation(conversationId);
    if (!mounted || state.conversationId != conversationId) return;
    state = state.copyWith(messages: msgs);
  }

  Future<void> startNewChat() async {
    _activeStream?.cancel();

    // 1. If current conversation had messages, ensure it has a good title
    if (state.conversationId != null && state.messages.isNotEmpty) {
      final convId = state.conversationId!;
      final allConvs = await _db.getConversations();
      final match = allConvs.where((c) => c.id == convId).firstOrNull;
      if (match != null) {
        final firstUserMsg = state.messages.where((m) => m.role == 'user').firstOrNull;
        if (firstUserMsg != null &&
            (match.title.isEmpty ||
                match.title == 'Neuer Chat' ||
                match.title == '+ New Chat' ||
                match.title == 'New Chat')) {
          final title = firstUserMsg.content.length > 25
              ? '${firstUserMsg.content.substring(0, 25)}...'
              : firstUserMsg.content;
          await _ref.read(sidebarProvider.notifier).updateTitle(convId, title);
        }
      }
    }

    // 2. If current conversation already exists and has 0 messages, just reset persona to Standard!
    if (state.conversationId != null && state.messages.isEmpty) {
      _ref.read(sidebarProvider.notifier).setActiveConversation(state.conversationId!);
      _ref.read(workspaceProvider.notifier).setActiveConversation(state.conversationId!);
      state = state.copyWith(activePersonaName: 'Standard');
      return;
    }

    // 3. Create a brand new conversation in the database & sidebar with Standard persona
    final title = I18n.isGerman ? 'Neuer Chat' : 'New Chat';
    final newConv = await _ref.read(sidebarProvider.notifier).createNewConversation(
      title: title,
      persona: 'Standard',
    );

    _ref.read(workspaceProvider.notifier).setActiveConversation(newConv.id);

    // 4. Set state to the new conversation
    state = state.copyWith(
      conversationId: newConv.id,
      activePersonaName: 'Standard',
      messages: [],
      isGenerating: false,
      errorMessage: null,
      clearCanvas: true,
      isCanvasOpen: false,
    );
  }

  void setPersona(String personaName) {
    state = state.copyWith(activePersonaName: personaName);
    if (state.conversationId != null && state.conversationId!.isNotEmpty) {
      _ref.read(sidebarProvider.notifier).updatePersona(state.conversationId!, personaName);
    }
  }

  void setTemperature(double temp) {
    state = state.copyWith(temperature: temp);
  }

  void openInCanvas(String code, String language) {
    state = state.copyWith(
      isCanvasOpen: true,
      canvasContent: code,
      canvasLanguage: language,
    );
  }

  void closeCanvas() {
    state = state.copyWith(isCanvasOpen: false);
  }

  Future<void> sendMessage(
    String text,
    String modelName, {
    List<AttachedFile>? attachedFiles,
    WorkspaceInfo? workspace,
  }) async {
    final wsNotifier = _ref.read(workspaceProvider.notifier);
    final wsState = _ref.read(workspaceProvider);
    final effectiveWorkspace = workspace ?? wsState.workspace;
    final effectiveFiles = List<AttachedFile>.from(attachedFiles ?? wsState.attachedFiles);

    // Dynamic File Ingestion & RepoMap from Workspace:
    String? repoMap;
    if (effectiveWorkspace != null) {
      final textLower = text.toLowerCase();
      final alreadyAttachedPaths = effectiveFiles.map((f) => f.path).toSet();

      // A. Explicit mentions in user query
      for (final relPath in effectiveWorkspace.files) {
        final filename = p.basename(relPath).toLowerCase();
        final relPathLower = relPath.toLowerCase();

        final isMentioned = textLower.contains(relPathLower) ||
            (filename.length > 3 && textLower.contains(filename));

        if (isMentioned) {
          final fullPath = p.join(effectiveWorkspace.path, relPath);
          if (!alreadyAttachedPaths.contains(fullPath)) {
            final autoFile = await AttachedFile.fromPath(
              fullPath,
              workspaceRoot: effectiveWorkspace.path,
            );
            if (autoFile != null) {
              effectiveFiles.add(autoFile);
              alreadyAttachedPaths.add(fullPath);
            }
          }
        }
      }

      // B. Smart Heuristic Retrieval (Keyword & Symbol Matcher)
      final relevantMatches = await WorkspaceSearchService.searchRelevantFiles(
        text,
        effectiveWorkspace.path,
        effectiveWorkspace.files,
        excludedPaths: alreadyAttachedPaths,
        maxResults: 2,
      );
      for (final match in relevantMatches) {
        if (!alreadyAttachedPaths.contains(match.path)) {
          effectiveFiles.add(match);
          alreadyAttachedPaths.add(match.path);
        }
      }

      // C. If effectiveFiles is STILL empty, auto-load at most 1 primary overview file
      if (effectiveFiles.isEmpty) {
        const overviewCandidates = {'readme.md', 'pubspec.yaml', 'package.json', 'cargo.toml', 'pyproject.toml'};
        for (final relPath in effectiveWorkspace.files) {
          final base = p.basename(relPath).toLowerCase();
          if (overviewCandidates.contains(base)) {
            final fullPath = p.join(effectiveWorkspace.path, relPath);
            final overviewFile = await AttachedFile.fromPath(
              fullPath,
              workspaceRoot: effectiveWorkspace.path,
              maxLines: 250,
            );
            if (overviewFile != null) {
              effectiveFiles.add(overviewFile);
              break;
            }
          }
        }
      }

      // D. Generate Compact Repo Map (AST / Symbol Outline)
      if (effectiveWorkspace.files.isNotEmpty) {
        repoMap = await RepoMapService.generateRepoMap(
          effectiveWorkspace.path,
          effectiveWorkspace.files,
          maxSymbols: 60,
        );
      }
    }

    if (text.trim().isEmpty && effectiveFiles.isEmpty) return;
    if (state.isGenerating) return;

    // Build the complete prompt payload
    String promptPayload = text.trim();
    if (effectiveFiles.isNotEmpty || effectiveWorkspace != null) {
      final buffer = StringBuffer();
      if (effectiveWorkspace != null) {
        buffer.writeln('### Project Workspace: `${effectiveWorkspace.name}`${effectiveWorkspace.gitBranch != null ? ' (Git Branch: `${effectiveWorkspace.gitBranch}`)' : ''}');
        if (effectiveWorkspace.files.isNotEmpty) {
          buffer.writeln('#### Project File Structure:\n```\n${effectiveWorkspace.formattedFileTree}\n```');
        }
        if (repoMap != null && repoMap.isNotEmpty) {
          buffer.writeln('#### Workspace Code Outline (Key Symbols):\n$repoMap');
        }
        buffer.writeln('#### Workspace Tools:\nYou have access to the `read_file(file_path)` function. When you need to read or verify code from any file in the workspace, call `read_file` with the relative file path.');
      }
      if (effectiveFiles.isNotEmpty) {
        buffer.writeln('#### Attached Context Files (Full Content):');
        for (final file in effectiveFiles) {
          buffer.writeln(file.toMarkdownBlock());
          buffer.writeln();
        }
      }
      if (text.trim().isNotEmpty) {
        buffer.writeln('#### User Request:');
        buffer.writeln(text.trim());
      }
      promptPayload = buffer.toString().trim();
    }

    // 1. Ensure active conversation exists
    String convId = state.conversationId ?? '';
    bool isFirstMessageInConv = false;
    final titleSeed = text.trim().isNotEmpty
        ? text.trim()
        : (effectiveFiles.isNotEmpty ? 'File: ${effectiveFiles.first.name}' : 'New Chat');

    if (convId.isEmpty) {
      final newConv = await _ref.read(sidebarProvider.notifier).createNewConversation(
        title: titleSeed.length > 25 ? '${titleSeed.substring(0, 25)}...' : titleSeed,
        persona: state.activePersonaName,
      );
      convId = newConv.id;
      isFirstMessageInConv = true;
      state = state.copyWith(conversationId: convId);
    } else {
      // Check if this conversation had 0 user messages so far
      if (!state.messages.any((m) => m.role == 'user')) {
        isFirstMessageInConv = true;
        final previewTitle = titleSeed.length > 25 ? '${titleSeed.substring(0, 25)}...' : titleSeed;
        await _ref.read(sidebarProvider.notifier).updateTitle(convId, previewTitle);
      }
    }

    // 2. Add user message with clean display content (only explicitly attached pills encoded)
    final now = DateTime.now();
    String displayContent = text.trim();
    final explicitAttached = attachedFiles ?? wsState.attachedFiles;
    if (explicitAttached.isNotEmpty) {
      final fileNames = explicitAttached.map((f) => f.name).join(', ');
      displayContent = '[attached:$fileNames]${displayContent.isNotEmpty ? '\n$displayContent' : ''}';
    }

    final userMsg = Message(
      id: '${now.millisecondsSinceEpoch}_user',
      conversationId: convId,
      role: 'user',
      content: displayContent.isNotEmpty ? displayContent : (effectiveWorkspace != null ? effectiveWorkspace.name : 'Message'),
      createdAt: now,
    );
    await _db.saveMessage(userMsg);

    // 3. Add placeholder assistant message
    final assistantMsgId = '${now.millisecondsSinceEpoch + 1}_assistant';
    final assistantMsg = Message(
      id: assistantMsgId,
      conversationId: convId,
      role: 'assistant',
      content: '',
      createdAt: DateTime.now(),
    );

    final updatedMessages = [...state.messages, userMsg, assistantMsg];
    final hasPdf = effectiveFiles.any((f) => f.extension == '.pdf');
    state = state.copyWith(
      messages: updatedMessages,
      isGenerating: true,
      errorMessage: null,
      statusMessage: hasPdf ? (I18n.isGerman ? 'Lese PDF-Dokument ein...' : 'Analyzing PDF document...') : null,
    );

    // 4. Calculate dynamic token budget and num_ctx for Ollama
    final totalTokens = ContextManager.estimateTokens(promptPayload);
    int dynamicNumCtx = 2048;
    if (totalTokens > 800) {
      dynamicNumCtx = (totalTokens + 1024).clamp(2048, 4096);
    }

    // Prepare message payload with sliding window bounded by dynamicNumCtx
    final rawHistory = updatedMessages
        .where((m) => m.role == 'user' || (m.role == 'assistant' && m.id != assistantMsgId))
        .toList();
    final windowed = ContextManager.applySlidingWindow(
      messages: rawHistory,
      maxTokens: dynamicNumCtx - 500,
    );
    final List<Map<String, dynamic>> promptMessages = windowed.map<Map<String, dynamic>>((m) {
      if (m.id == userMsg.id) {
        return <String, dynamic>{'role': 'user', 'content': promptPayload};
      }
      return <String, dynamic>{'role': m.role, 'content': m.content};
    }).toList();

    // Add system persona if defined
    final matchedPersona = Persona.defaultPersonas.firstWhere(
      (p) => p.name.toLowerCase() == state.activePersonaName.toLowerCase(),
      orElse: () => Persona.defaultPersonas.first,
    );
    if (matchedPersona.systemPrompt.trim().isNotEmpty) {
      promptMessages.insert(0, {
        'role': 'system',
        'content': matchedPersona.systemPrompt,
      });
    }

    final rawStreamBuffer = StringBuffer();
    final stopwatch = Stopwatch()..start();
    int tokenEstimate = 0;

    // Only clear standalone attachments if no workspace is active (preserve workspace files across conversation)
    if (wsState.workspace == null) {
      wsNotifier.clearAttachments();
    }

    final List<Map<String, dynamic>> tools = effectiveWorkspace != null
        ? [
            {
              'type': 'function',
              'function': {
                'name': 'read_file',
                'description': 'Reads the content of a specific file in the workspace to inspect code details',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'file_path': {
                      'type': 'string',
                      'description': 'Relative path of the file in the workspace (e.g. lib/core/services/git_service.dart)',
                    },
                  },
                  'required': ['file_path'],
                },
              },
            },
          ]
        : [];

    Future<void> runStream({bool withTools = true}) async {
      try {
        Map<String, dynamic>? pendingToolCall;

        final stream = _ollama.streamChat(
          modelName,
          promptMessages,
          temperature: state.temperature,
          numCtx: dynamicNumCtx,
          tools: withTools && tools.isNotEmpty ? tools : null,
          onToolCall: (toolCall) {
            pendingToolCall = toolCall;
          },
        );

        _activeStream = stream.listen(
          (chunk) {
            if (!mounted) return;
            if (state.statusMessage != null) {
              state = state.copyWith(statusMessage: null);
            }
            rawStreamBuffer.write(chunk);
            tokenEstimate++;

            final parsed = ThinkParser.parse(rawStreamBuffer.toString());

            final currentAssistant = Message(
              id: assistantMsgId,
              conversationId: convId,
              role: 'assistant',
              content: parsed.content,
              thinkContent: parsed.thinkContent.isNotEmpty ? parsed.thinkContent : null,
              createdAt: now,
              tokens: tokenEstimate,
              generationDurationMs: stopwatch.elapsedMilliseconds,
            );

            final msgs = List<Message>.from(state.messages);
            if (msgs.isNotEmpty && msgs.last.id == assistantMsgId) {
              msgs[msgs.length - 1] = currentAssistant;
            }
            state = state.copyWith(messages: msgs);
          },
          onError: (err) {
            if (!mounted) return;
            if (withTools && err.toString().contains('400')) {
              runStream(withTools: false);
              return;
            }
            final msgs = state.messages.where((m) => m.id != assistantMsgId).toList();
            state = state.copyWith(
              messages: msgs,
              isGenerating: false,
              clearStatusMessage: true,
              errorMessage: 'Stream error: $err',
            );
          },
          onDone: () async {
            // Check if model called a tool
            if (pendingToolCall != null) {
              final fn = pendingToolCall!['function'];
              if (fn != null && fn['name'] == 'read_file') {
                final args = fn['arguments'];
                String? reqPath;
                if (args is Map) {
                  reqPath = args['file_path'] as String?;
                } else if (args is String) {
                  try {
                    final decoded = jsonDecode(args);
                    reqPath = decoded['file_path'] as String?;
                  } catch (_) {}
                }

                if (reqPath != null && effectiveWorkspace != null && mounted) {
                  state = state.copyWith(statusMessage: 'Reading $reqPath...');

                  final fullPath = p.join(effectiveWorkspace.path, reqPath);
                  final file = await AttachedFile.fromPath(
                    fullPath,
                    workspaceRoot: effectiveWorkspace.path,
                    maxLines: 400,
                  );

                  promptMessages.add({
                    'role': 'assistant',
                    'content': '',
                    'tool_calls': [pendingToolCall],
                  });
                  promptMessages.add({
                    'role': 'tool',
                    'content': file != null ? file.content : 'Error: File not found or unreadable.',
                  });

                  rawStreamBuffer.clear();
                  await runStream(withTools: false);
                  return;
                }
              }
            }

            stopwatch.stop();
            if (!mounted) return;

            if (rawStreamBuffer.isEmpty) {
              final msgs = state.messages.where((m) => m.id != assistantMsgId).toList();
              state = state.copyWith(messages: msgs, isGenerating: false, clearStatusMessage: true);
              return;
            }

            final parsed = ThinkParser.parse(rawStreamBuffer.toString());

            final finalizedMsg = Message(
              id: assistantMsgId,
              conversationId: convId,
              role: 'assistant',
              content: parsed.content,
              thinkContent: parsed.thinkContent.isNotEmpty ? parsed.thinkContent : null,
              createdAt: now,
              tokens: tokenEstimate,
              generationDurationMs: stopwatch.elapsedMilliseconds,
            );

            await _db.saveMessage(finalizedMsg);
            if (!mounted) return;

            state = state.copyWith(isGenerating: false, clearStatusMessage: true);

            // Auto-summarize title in background if it was the first user message
            if (isFirstMessageInConv) {
              try {
                final title = await TitleService.generateTitle([userMsg], modelOverride: modelName);
                if (title.isNotEmpty && title != 'New Chat' && title != 'Neuer Chat') {
                  await _ref.read(sidebarProvider.notifier).updateTitle(convId, title);
                }
              } catch (_) {
                // Title generation is non-critical background task
              }
            }
          },
          cancelOnError: true,
        );
      } catch (err) {
        if (withTools && err.toString().contains('400')) {
          runStream(withTools: false);
        } else {
          state = state.copyWith(
            isGenerating: false,
            clearStatusMessage: true,
            errorMessage: 'Ollama error: $err',
          );
        }
      }
    }

    await runStream(withTools: true);
  }

  void stopGeneration() {
    _activeStream?.cancel();
    state = state.copyWith(isGenerating: false);
  }

  @override
  void dispose() {
    _activeStream?.cancel();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
