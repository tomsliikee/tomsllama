import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/message.dart';
import '../../../../core/models/persona.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/ollama_service.dart';
import '../../../../core/services/title_service.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/services/context_manager.dart';
import '../../../../core/services/workspace_service.dart';
import 'package:path/path.dart' as p;
import '../../../../core/utils/think_parser.dart';
import '../../../../core/models/attached_file.dart';
import '../../../../core/models/workspace_info.dart';
import '../../../../core/services/hardware_calibration_service.dart';
import '../../sidebar/controllers/sidebar_controller.dart';
import '../../chat/controllers/workspace_controller.dart';
import '../../../../core/models/workspace.dart';
import '../../../../core/models/workspace_context_file.dart';

enum ChatExecutionMode {
  schnell,
  optimal,
  thinking,
}

class ChatState {
  final String? conversationId;
  final List<Message> messages;
  final bool isGenerating;
  final String activePersonaName;
  final ChatExecutionMode mode;
  final bool isCanvasOpen;
  final String? canvasContent;
  final String? canvasLanguage;
  final String? errorMessage;
  final String? statusMessage;
  final int? statusTokens;

  const ChatState({
    this.conversationId,
    this.messages = const [],
    this.isGenerating = false,
    this.activePersonaName = 'Standard',
    this.mode = ChatExecutionMode.optimal,
    this.isCanvasOpen = false,
    this.canvasContent,
    this.canvasLanguage,
    this.errorMessage,
    this.statusMessage,
    this.statusTokens,
  });

  ChatState copyWith({
    String? conversationId,
    List<Message>? messages,
    bool? isGenerating,
    String? activePersonaName,
    ChatExecutionMode? mode,
    bool? isCanvasOpen,
    String? canvasContent,
    String? canvasLanguage,
    String? errorMessage,
    String? statusMessage,
    int? statusTokens,
    bool clearCanvas = false,
    bool clearStatusMessage = false,
    bool clearStatusTokens = false,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      activePersonaName: activePersonaName ?? this.activePersonaName,
      mode: mode ?? this.mode,
      isCanvasOpen: isCanvasOpen ?? this.isCanvasOpen,
      canvasContent: clearCanvas ? null : (canvasContent ?? this.canvasContent),
      canvasLanguage: clearCanvas ? null : (canvasLanguage ?? this.canvasLanguage),
      errorMessage: errorMessage,
      statusMessage: clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
      statusTokens: clearStatusTokens ? null : (statusTokens ?? this.statusTokens),
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final DatabaseService _db = DatabaseService();
  final OllamaService _ollama = OllamaService();
  final Ref _ref;
  StreamSubscription<String>? _activeStream;
  String? _activeAssistantId;

  // Stream chunks are coalesced before they reach the UI: every state update
  // re-parses and re-lays-out the whole answer, which costs CPU the model needs.
  static const Duration _streamPublishInterval = Duration(milliseconds: 50);
  Timer? _publishTimer;
  void Function()? _publishPending;

  // Full prompt payload (with attached file bodies) of the most recent user turn.
  // Only the display text is persisted, so regenerate needs this to resend the files.
  String? _lastPayloadMessageId;
  String? _lastPayload;

  ChatNotifier(this._ref) : super(const ChatState());

  /// Removes the `[attached:a, b]` display prefix that [sendMessage] stores in
  /// front of a user message, leaving the text the user typed.
  static String stripAttachmentPrefix(String content) {
    if (!content.startsWith('[attached:')) return content;
    final endIdx = content.indexOf(']');
    if (endIdx == -1) return content;
    return content.substring(endIdx + 1).trim();
  }

  /// Cancels the running stream and keeps what was generated so far.
  ///
  /// The user message is already in the database at this point; without saving
  /// the partial answer the conversation would reload with an unanswered turn.
  void _interruptGeneration() {
    _activeStream?.cancel();
    _activeStream = null;
    // Bring state up to the last received chunk so the saved partial is complete.
    _flushPendingPublish();
    final assistantId = _activeAssistantId;
    _activeAssistantId = null;
    if (!state.isGenerating) return;

    var msgs = state.messages;
    final last = msgs.lastOrNull;
    if (last != null && last.role == 'assistant' && last.id == assistantId) {
      final hasOutput = last.content.trim().isNotEmpty || (last.thinkContent?.trim().isNotEmpty ?? false);
      if (hasOutput) {
        unawaited(_db.saveMessage(last));
      } else {
        msgs = msgs.sublist(0, msgs.length - 1);
      }
    }

    state = state.copyWith(
      messages: msgs,
      isGenerating: false,
      clearStatusMessage: true,
      clearStatusTokens: true,
    );
  }

  void _flushPendingPublish() {
    _publishTimer?.cancel();
    _publishTimer = null;
    final publish = _publishPending;
    _publishPending = null;
    publish?.call();
  }

  void _dropPendingPublish() {
    _publishTimer?.cancel();
    _publishTimer = null;
    _publishPending = null;
  }

  static String _describeError(Object err) {
    if (err is SocketException || err is http.ClientException) {
      return I18n.ollamaUnreachable(OllamaService().baseUrl);
    }
    return I18n.generationFailed(err.toString());
  }

  Future<void> loadConversation(String conversationId) async {
    _interruptGeneration();

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
    _interruptGeneration();

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
    _ref.read(workspaceProvider.notifier).clearWorkspace();

    // 4. Set state to the new conversation
    state = state.copyWith(
      conversationId: newConv.id,
      activePersonaName: 'Standard',
      messages: [],
      isGenerating: false,
      errorMessage: null,
      clearCanvas: true,
      isCanvasOpen: false,
      clearStatusMessage: true,
      clearStatusTokens: true,
    );
  }

  void setPersona(String personaName) {
    state = state.copyWith(activePersonaName: personaName);
    if (state.conversationId != null && state.conversationId!.isNotEmpty) {
      _ref.read(sidebarProvider.notifier).updatePersona(state.conversationId!, personaName);
    }
  }

  void setMode(ChatExecutionMode mode) {
    state = state.copyWith(mode: mode);
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
    Message? regenerateFrom,
  }) async {
    final wsNotifier = _ref.read(workspaceProvider.notifier);
    final wsState = _ref.read(workspaceProvider);
    final isRegeneration = regenerateFrom != null;
    // A regenerated turn must not pick up files the user has staged for the next message.
    final explicitAttached = isRegeneration ? const <AttachedFile>[] : (attachedFiles ?? wsState.attachedFiles);

    if (!isRegeneration && text.trim().isEmpty && explicitAttached.isEmpty) return;
    if (state.isGenerating) return;

    // 1. Ensure active conversation exists
    String convId = state.conversationId ?? '';
    bool isFirstMessageInConv = false;
    final titleSeed = text.trim().isNotEmpty
        ? text.trim()
        : (explicitAttached.isNotEmpty
            ? I18n.attachedFilePrefix(explicitAttached.first.name)
            : I18n.newChatTitle);

    if (convId.isEmpty) {
      final newConv = await _ref.read(sidebarProvider.notifier).createNewConversation(
        title: titleSeed.length > 25 ? '${titleSeed.substring(0, 25)}...' : titleSeed,
        persona: state.activePersonaName,
      );
      convId = newConv.id;
      isFirstMessageInConv = true;
      wsNotifier.setActiveConversation(convId);
      state = state.copyWith(conversationId: convId);
    } else {
      // Check if this conversation had 0 user messages so far
      if (!state.messages.any((m) => m.role == 'user')) {
        isFirstMessageInConv = true;
        final previewTitle = titleSeed.length > 25 ? '${titleSeed.substring(0, 25)}...' : titleSeed;
        await _ref.read(sidebarProvider.notifier).updateTitle(convId, previewTitle);
      }
    }

    // 2. Check if conversation belongs to a Claude-style Workspace with active context
    final allConvs = await _db.getConversations();
    final currentConv = allConvs.where((c) => c.id == convId).firstOrNull;
    final workspaceId = currentConv?.workspaceId;
    final isWorkspaceContextEnabled = currentConv?.isWorkspaceContextEnabled ?? true;

    Workspace? claudeWorkspace;
    List<WorkspaceContextFile> claudeWorkspaceFiles = const [];

    if (workspaceId != null && isWorkspaceContextEnabled) {
      claudeWorkspace = await _db.getWorkspace(workspaceId);
      if (claudeWorkspace != null) {
        claudeWorkspaceFiles = await _db.getWorkspaceFiles(workspaceId);
      }
    }

    // 3. Resolve attached files & legacy workspace
    // Legacy disk workspace is ONLY used if NOT in a Claude Workspace
    final effectiveWorkspace = claudeWorkspace == null ? (workspace ?? wsState.workspace) : null;
    final effectiveFiles = List<AttachedFile>.from(explicitAttached);

    // Dynamic File Ingestion: ONLY if user explicitly opened a disk workspace AND mentions files
    if (effectiveWorkspace != null && effectiveWorkspace.files.isNotEmpty) {
      final textLower = text.toLowerCase();
      final alreadyAttachedPaths = effectiveFiles.map((f) => f.path).toSet();

      // Only attach if user explicitly mentions the file name in their query
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
              maxLines: 250,
            );
            if (autoFile != null) {
              effectiveFiles.add(autoFile);
              alreadyAttachedPaths.add(fullPath);
            }
          }
        }
      }
    }

    // Build static system prompt (Persona + Claude Workspace Instructions + Knowledge Base Files + Project Repo Structure)
    // This prefix is identical across turns, allowing Ollama's KV-cache to hit on turn 2+ (reducing prompt eval from 45s to 1s).
    final matchedPersona = Persona.defaultPersonas.firstWhere(
      (p) => p.name.toLowerCase() == state.activePersonaName.toLowerCase(),
      orElse: () => Persona.defaultPersonas.first,
    );
    final systemPromptBuffer = StringBuffer();
    if (matchedPersona.systemPrompt.trim().isNotEmpty) {
      systemPromptBuffer.writeln(matchedPersona.systemPrompt.trim());
    }
    if (claudeWorkspace != null) {
      if (claudeWorkspace.prompt.trim().isNotEmpty) {
        if (systemPromptBuffer.isNotEmpty) systemPromptBuffer.writeln('\n');
        systemPromptBuffer.writeln('### Workspace Instructions & Rules (${claudeWorkspace.name}):\n${claudeWorkspace.prompt.trim()}');
      }
      if (claudeWorkspaceFiles.isNotEmpty) {
        if (systemPromptBuffer.isNotEmpty) systemPromptBuffer.writeln('\n');
        systemPromptBuffer.writeln('### Workspace Knowledge Base (${claudeWorkspace.name}):');
        for (final file in claudeWorkspaceFiles) {
          systemPromptBuffer.writeln(file.toMarkdownBlock());
          systemPromptBuffer.writeln();
        }
      }
    }
    if (effectiveWorkspace != null) {
      if (systemPromptBuffer.isNotEmpty) systemPromptBuffer.writeln('\n');
      systemPromptBuffer.writeln('### Project Workspace: `${effectiveWorkspace.name}`${effectiveWorkspace.gitBranch != null ? ' (Git Branch: `${effectiveWorkspace.gitBranch}`)' : ''}');
      if (effectiveWorkspace.files.isNotEmpty) {
        final previewFiles = effectiveWorkspace.files.take(20).join(', ');
        systemPromptBuffer.writeln('#### Project Files Preview: $previewFiles');
      }
      systemPromptBuffer.writeln('#### Workspace Tools:\nYou have access to the `read_file(file_path)` function. When you need to read or verify code from any file in the workspace, call `read_file` with the relative file path.');
    }

    // Build the user turn prompt payload (standalone attached files + query)
    String promptPayload = text.trim();
    if (effectiveFiles.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.writeln('#### Attached Context Files:');
      for (final file in effectiveFiles) {
        buffer.writeln(file.toMarkdownBlock());
        buffer.writeln();
      }
      if (text.trim().isNotEmpty) {
        buffer.writeln('#### User Request:');
        buffer.writeln(text.trim());
      }
      promptPayload = buffer.toString().trim();
    }
    if (isRegeneration && _lastPayloadMessageId == regenerateFrom.id && _lastPayload != null) {
      promptPayload = _lastPayload!;
    }

    // 2. Add user message with clean display content (only explicitly attached pills encoded)
    final now = DateTime.now();
    String displayContent = text.trim();
    if (explicitAttached.isNotEmpty) {
      final fileNames = explicitAttached.map((f) => f.name).join(', ');
      displayContent = '[attached:$fileNames]${displayContent.isNotEmpty ? '\n$displayContent' : ''}';
    }

    final Message userMsg;
    if (isRegeneration) {
      userMsg = regenerateFrom;
    } else {
      userMsg = Message(
        id: '${now.millisecondsSinceEpoch}_user',
        conversationId: convId,
        role: 'user',
        content: displayContent.isNotEmpty ? displayContent : (effectiveWorkspace != null ? effectiveWorkspace.name : 'Message'),
        createdAt: now,
        tokens: ContextManager.estimateTokens(displayContent),
      );
      await _db.saveMessage(userMsg);
    }
    _lastPayloadMessageId = userMsg.id;
    _lastPayload = promptPayload;

    // 3. Add placeholder assistant message
    final assistantMsgId = '${now.millisecondsSinceEpoch + 1}_assistant';
    final assistantMsg = Message(
      id: assistantMsgId,
      conversationId: convId,
      role: 'assistant',
      content: '',
      createdAt: DateTime.now(),
    );

    final updatedMessages = [...state.messages, if (!isRegeneration) userMsg, assistantMsg];
    _activeAssistantId = assistantMsgId;
    final hasPdf = effectiveFiles.any((f) => f.extension == '.pdf') ||
        claudeWorkspaceFiles.any((f) => f.extension == '.pdf');

    // 4. Discrete token budget and num_ctx tiers to prevent Ollama runner reload on CPU
    final systemTokens = ContextManager.estimateTokens(systemPromptBuffer.toString());
    final userTokens = ContextManager.estimateTokens(promptPayload);
    final totalTokens = systemTokens + userTokens;

    final hwEstimate = HardwareCalibrationService().estimatePrompt(
      tokens: totalTokens,
      mode: state.mode,
    );

    String? statusMsg;
    if (hasPdf) {
      statusMsg = I18n.readingPdf;
    } else if (totalTokens > 600) {
      final tokenStr = totalTokens >= 1000 ? '~${(totalTokens / 1000).toStringAsFixed(1)}k' : '$totalTokens';
      statusMsg = I18n.cpuEvaluatingContext(tokenStr, hwEstimate.durationDisplay);
    }

    state = state.copyWith(
      messages: updatedMessages,
      isGenerating: true,
      errorMessage: null,
      statusMessage: statusMsg,
      statusTokens: totalTokens > 600 ? totalTokens : null,
    );

    final double effectiveTemperature;
    switch (state.mode) {
      case ChatExecutionMode.schnell:
        effectiveTemperature = 0.3;
        break;
      case ChatExecutionMode.optimal:
        effectiveTemperature = 0.7;
        break;
      case ChatExecutionMode.thinking:
        effectiveTemperature = 0.6;
        break;
    }

    final budget = ContextManager.planBudget(
      systemTokens: systemTokens,
      promptTokens: userTokens,
      latestMessageTokens: userMsg.tokens,
    );
    final ollamaNumCtx = budget.numCtx;
    final slidingWindowBudget = budget.historyTokens;

    // Prepare message payload with sliding window bounded by slidingWindowBudget
    final rawHistory = updatedMessages
        .where((m) => m.role == 'user' || (m.role == 'assistant' && m.id != assistantMsgId))
        .toList();
    final windowed = ContextManager.applySlidingWindow(
      messages: rawHistory,
      maxTokens: slidingWindowBudget,
    );
    final List<Map<String, dynamic>> promptMessages = windowed.map<Map<String, dynamic>>((m) {
      if (m.id == userMsg.id) {
        return <String, dynamic>{'role': 'user', 'content': promptPayload};
      }
      return <String, dynamic>{'role': m.role, 'content': m.content};
    }).toList();

    // Insert system prompt at index 0
    if (systemPromptBuffer.isNotEmpty) {
      promptMessages.insert(0, {
        'role': 'system',
        'content': systemPromptBuffer.toString().trim(),
      });
    }

    final rawStreamBuffer = StringBuffer();
    final stopwatch = Stopwatch()..start();
    int tokenEstimate = 0;

    // Only clear standalone attachments if no workspace is active (preserve workspace files across conversation)
    if (wsState.workspace == null && !isRegeneration) {
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
          temperature: effectiveTemperature,
          numCtx: ollamaNumCtx,
          tools: withTools && tools.isNotEmpty ? tools : null,
          onToolCall: (toolCall) {
            pendingToolCall = toolCall;
          },
          onDoneMetrics: (metrics) {
            final promptCount = metrics['prompt_eval_count'] as int? ?? 0;
            final promptDurationNs = metrics['prompt_eval_duration'] as int? ?? 0;
            final evalCount = metrics['eval_count'] as int? ?? 0;
            final evalDurationNs = metrics['eval_duration'] as int? ?? 0;

            if (promptDurationNs > 0 || evalDurationNs > 0) {
              HardwareCalibrationService().recordMetrics(
                promptEvalCount: promptCount,
                promptEvalDurationNs: promptDurationNs,
                evalCount: evalCount,
                evalDurationNs: evalDurationNs,
                modelName: modelName,
              );
            }
          },
        );

        _activeStream = stream.listen(
          (chunk) {
            if (!mounted) return;
            if (state.statusMessage != null || state.statusTokens != null) {
              state = state.copyWith(
                clearStatusMessage: true,
                clearStatusTokens: true,
              );
            }
            rawStreamBuffer.write(chunk);
            tokenEstimate++;

            _publishPending = () {
              if (!mounted) return;
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
            };
            _publishTimer ??= Timer(_streamPublishInterval, _flushPendingPublish);
          },
          onError: (err) {
            _dropPendingPublish();
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
              clearStatusTokens: true,
              errorMessage: _describeError(err),
            );
          },
          onDone: () async {
            // State is what the user sees and what gets finalized; show the last chunks first.
            _flushPendingPublish();
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
                  state = state.copyWith(statusMessage: I18n.readingFile(reqPath));

                  final fullPath = await WorkspaceService.resolveInsideWorkspace(effectiveWorkspace.path, reqPath);
                  final file = fullPath == null
                      ? null
                      : await AttachedFile.fromPath(
                          fullPath,
                          workspaceRoot: effectiveWorkspace.path,
                          maxLines: 400,
                        );
                  // The user may have stopped or switched chats while the file was read.
                  if (!mounted || _activeAssistantId != assistantMsgId) return;

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
              state = state.copyWith(
                messages: msgs,
                isGenerating: false,
                clearStatusMessage: true,
                clearStatusTokens: true,
              );
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

            _activeAssistantId = null;
            await _db.saveMessage(finalizedMsg);
            if (!mounted) return;

            state = state.copyWith(
              isGenerating: false,
              clearStatusMessage: true,
              clearStatusTokens: true,
            );

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
            clearStatusTokens: true,
            errorMessage: _describeError(err),
          );
        }
      }
    }

    await runStream(withTools: true);
  }

  void stopGeneration() {
    _interruptGeneration();
  }

  /// Replaces the last answer: drops everything after the last user message and
  /// generates again for that same message instead of sending it a second time.
  Future<void> regenerateLast(String modelName) async {
    if (state.isGenerating) return;
    final idx = state.messages.lastIndexWhere((m) => m.role == 'user');
    if (idx == -1) return;

    final userMsg = state.messages[idx];
    for (final stale in state.messages.skip(idx + 1)) {
      await _db.deleteMessage(stale.id);
    }
    state = state.copyWith(messages: state.messages.sublist(0, idx + 1));

    await sendMessage(
      stripAttachmentPrefix(userMsg.content),
      modelName,
      regenerateFrom: userMsg,
    );
  }

  @override
  void dispose() {
    _dropPendingPublish();
    _activeStream?.cancel();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
