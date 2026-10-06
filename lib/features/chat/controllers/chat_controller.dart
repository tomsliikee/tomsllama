export '../../../../core/models/chat_execution_mode.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/chat_execution_mode.dart';
import '../../../../core/models/message.dart';
import '../../../../core/models/persona.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/ollama_service.dart';
import '../../../../core/services/title_service.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/services/context_manager.dart';
import '../../../../core/services/workspace_service.dart';
import '../../../../core/services/summary_service.dart';
import '../../models/controllers/model_controller.dart';
import '../../settings/controllers/settings_controller.dart';
import 'package:path/path.dart' as p;
import '../../../../core/utils/think_parser.dart';
import '../../../../core/models/attached_file.dart';
import '../../../../core/models/workspace_info.dart';
import '../../../../core/services/hardware_calibration_service.dart';
import '../../sidebar/controllers/sidebar_controller.dart';
import '../../chat/controllers/workspace_controller.dart';
import '../../../../core/models/workspace.dart';
import '../../../../core/models/workspace_context_file.dart';


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

  /// Seconds the wait before the first token is expected to take, for the countdown.
  final int? statusEtaSeconds;

  /// Conversations with an answer in progress, including ones not on screen.
  final Set<String> generatingConversationIds;

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
    this.statusEtaSeconds,
    this.generatingConversationIds = const {},
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
    int? statusEtaSeconds,
    Set<String>? generatingConversationIds,
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
      // The countdown belongs to the token status and is cleared with it.
      statusEtaSeconds: clearStatusTokens ? null : (statusEtaSeconds ?? this.statusEtaSeconds),
      generatingConversationIds: generatingConversationIds ?? this.generatingConversationIds,
    );
  }
}

/// One answer being generated. It belongs to its conversation, not to whatever
/// is on screen, so it keeps running and collecting output when the user opens
/// another chat and is picked up again when they come back.
class _Generation {
  final String conversationId;
  final String assistantMsgId;

  /// Live message list of the conversation, ending in the assistant message being written.
  List<Message> messages;
  String? statusMessage;
  int? statusTokens;
  int? statusEtaSeconds;

  StreamSubscription<String>? stream;
  bool cancelled = false;

  // Stream chunks are coalesced before they reach the UI: every state update
  // re-parses and re-lays-out the whole answer, which costs CPU the model needs.
  Timer? _publishTimer;
  void Function()? _publishPending;

  _Generation({
    required this.conversationId,
    required this.assistantMsgId,
    required this.messages,
  });

  void schedulePublish(Duration interval, void Function() publish) {
    _publishPending = publish;
    _publishTimer ??= Timer(interval, flushPending);
  }

  void flushPending() {
    _publishTimer?.cancel();
    _publishTimer = null;
    final publish = _publishPending;
    _publishPending = null;
    publish?.call();
  }

  void dropPending() {
    _publishTimer?.cancel();
    _publishTimer = null;
    _publishPending = null;
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final DatabaseService _db = DatabaseService();
  final OllamaService _ollama = OllamaService();
  final Ref _ref;
  static const Duration _streamPublishInterval = Duration(milliseconds: 50);

  final Map<String, _Generation> _generations = {};

  // The prompt prefix (model, system prompt, context size) each conversation was
  // last answered with. While it is unchanged and the model is still loaded,
  // Ollama has that prefix cached and only the new turn needs evaluating.
  final Map<String, String> _cachedPrefixes = {};

  // A failed answer in a chat that was not on screen is shown when it is opened again.
  final Map<String, String> _lastErrors = {};

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

  /// Mirrors a generation into [state] when its conversation is the one on screen.
  void _sync(_Generation gen) {
    if (!mounted) return;
    final generating = _generations.keys.toSet();
    if (state.conversationId == gen.conversationId) {
      state = state.copyWith(
        messages: gen.messages,
        isGenerating: true,
        statusMessage: gen.statusMessage,
        statusTokens: gen.statusTokens,
        statusEtaSeconds: gen.statusEtaSeconds,
        clearStatusMessage: gen.statusMessage == null,
        clearStatusTokens: gen.statusTokens == null,
        generatingConversationIds: generating,
      );
    } else if (generating.length != state.generatingConversationIds.length ||
        !generating.containsAll(state.generatingConversationIds)) {
      state = state.copyWith(generatingConversationIds: generating, errorMessage: state.errorMessage);
    }
  }

  void _finish(_Generation gen, {String? error}) {
    gen.dropPending();
    if (identical(_generations[gen.conversationId], gen)) {
      _generations.remove(gen.conversationId);
    }
    if (error != null) _lastErrors[gen.conversationId] = error;
    if (!mounted) return;

    final generating = _generations.keys.toSet();
    if (state.conversationId == gen.conversationId) {
      state = state.copyWith(
        messages: gen.messages,
        isGenerating: false,
        clearStatusMessage: true,
        clearStatusTokens: true,
        errorMessage: error,
        generatingConversationIds: generating,
      );
    } else {
      state = state.copyWith(generatingConversationIds: generating, errorMessage: state.errorMessage);
    }
  }

  /// Cancels the generation of [conversationId], if there is one.
  ///
  /// With [keepPartial] the text generated so far is saved: the user message is
  /// already in the database, and without the partial answer the conversation
  /// would reload with an unanswered turn.
  void _interrupt(String? conversationId, {bool keepPartial = true}) {
    final gen = _generations[conversationId];
    if (gen == null) return;

    gen.cancelled = true;
    gen.stream?.cancel();
    // Bring the message up to the last received chunk so the saved partial is complete.
    if (keepPartial) {
      gen.flushPending();
    } else {
      gen.dropPending();
    }

    final last = gen.messages.lastOrNull;
    if (last != null && last.id == gen.assistantMsgId) {
      final hasOutput = last.content.trim().isNotEmpty || (last.thinkContent?.trim().isNotEmpty ?? false);
      if (keepPartial && hasOutput) {
        unawaited(_db.saveMessage(last));
      } else {
        gen.messages = gen.messages.sublist(0, gen.messages.length - 1);
      }
    }

    _finish(gen);
  }

  static String _describeError(Object err) {
    if (err is SocketException || err is http.ClientException) {
      return I18n.ollamaUnreachable(OllamaService().baseUrl);
    }
    return I18n.generationFailed(err.toString());
  }

  /// Shows [conversationId]. A generation running in the chat being left keeps
  /// going in the background; one running in the chat being opened is resumed live.
  Future<void> loadConversation(String conversationId) async {
    _ref.read(workspaceProvider.notifier).setActiveConversation(conversationId);

    // Retrieve the persona saved specifically for this conversation
    final conv = await _db.getConversation(conversationId);
    final persona = conv?.persona ?? 'Standard';

    final running = _generations[conversationId];
    state = state.copyWith(
      conversationId: conversationId,
      activePersonaName: persona,
      messages: running?.messages,
      isGenerating: running != null,
      statusMessage: running?.statusMessage,
      statusTokens: running?.statusTokens,
      statusEtaSeconds: running?.statusEtaSeconds,
      clearStatusMessage: running?.statusMessage == null,
      clearStatusTokens: running?.statusTokens == null,
      errorMessage: _lastErrors[conversationId],
      clearCanvas: true,
      isCanvasOpen: false,
    );
    // The live list already holds everything the database has, plus the answer in progress.
    if (running != null) return;

    final msgs = await _db.getMessagesForConversation(conversationId);
    if (!mounted || state.conversationId != conversationId) return;
    final started = _generations[conversationId];
    state = state.copyWith(messages: started?.messages ?? msgs, errorMessage: state.errorMessage);
  }

  Future<void> startNewChat() async {
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

    // The setup below awaits file and database work. Pin the conversation's
    // messages now so a chat switch in between cannot mix two conversations.
    final baseMessages = state.conversationId == convId ? state.messages : const <Message>[];

    // 2. Check if conversation belongs to a Claude-style Workspace with active context
    final currentConv = await _db.getConversation(convId);
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
    final customInstructions = _ref.read(appSettingsProvider).customInstructions.trim();
    if (customInstructions.isNotEmpty) {
      if (systemPromptBuffer.isNotEmpty) systemPromptBuffer.writeln('\n');
      systemPromptBuffer.writeln('### User Instructions:\n$customInstructions');
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

    // The summary of compacted turns goes last: everything above stays an
    // identical prefix across turns, so only this part is re-evaluated when it changes.
    final previousSummary = currentConv?.summary;
    final summaryThroughId = currentConv?.summaryThroughId;
    if (previousSummary != null && previousSummary.trim().isNotEmpty) {
      if (systemPromptBuffer.isNotEmpty) systemPromptBuffer.writeln('\n');
      systemPromptBuffer.writeln('### Earlier in this conversation (summary of turns no longer shown):\n${previousSummary.trim()}');
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

    final updatedMessages = [...baseMessages, if (!isRegeneration) userMsg, assistantMsg];
    final gen = _Generation(
      conversationId: convId,
      assistantMsgId: assistantMsgId,
      messages: updatedMessages,
    );
    final hasPdf = effectiveFiles.any((f) => f.extension == '.pdf') ||
        claudeWorkspaceFiles.any((f) => f.extension == '.pdf');

    // 4. Discrete token budget and num_ctx tiers to prevent Ollama runner reload on CPU
    final systemTokens = ContextManager.estimateTokens(systemPromptBuffer.toString());
    final userTokens = ContextManager.estimateTokens(promptPayload);
    // The wait estimate needs the final prompt and is filled in further down.
    gen.statusMessage = hasPdf ? I18n.readingPdf : null;
    _generations[convId] = gen;
    _lastErrors.remove(convId);
    _sync(gen);

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

    // What the daemon says this model can do. Unknown (older Ollama) leaves
    // the request as it was and falls back to the HTTP 400 retry below.
    final modelInfo = _ref.read(modelProvider).models.where((m) => m.name == modelName).firstOrNull;
    final bool? think;
    if (modelInfo?.supportsThinking != true) {
      think = null;
    } else if (state.mode == ChatExecutionMode.thinking) {
      think = true;
    } else if (state.mode == ChatExecutionMode.schnell) {
      think = false;
    } else {
      think = null;
    }

    final budget = ContextManager.planBudget(
      systemTokens: systemTokens,
      promptTokens: userTokens,
      latestMessageTokens: userMsg.tokens,
      maxContext: modelInfo?.contextLength,
    );
    final ollamaNumCtx = budget.numCtx;
    final slidingWindowBudget = budget.historyTokens;

    // Prepare message payload with sliding window bounded by slidingWindowBudget
    // Turns already folded into the summary are not sent again.
    final summarizedCount = summaryThroughId == null
        ? 0
        : updatedMessages.indexWhere((m) => m.id == summaryThroughId) + 1;
    final rawHistory = updatedMessages
        .skip(summarizedCount)
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

    // How long until the first token: the model may have to be loaded, and only
    // the part of the prompt that Ollama does not have cached is evaluated.
    final prefixKey = '$modelName|$ollamaNumCtx|${systemPromptBuffer.toString().hashCode}|$summarizedCount';
    final modelLoaded = await _ollama.isModelLoaded(modelName) ?? true;
    if (!mounted || gen.cancelled) return;

    final lastAnswer = windowed.where((m) => m.role == 'assistant').lastOrNull;
    final int uncachedTokens;
    if (modelLoaded && _cachedPrefixes[convId] == prefixKey) {
      uncachedTokens = userTokens + (lastAnswer == null ? 0 : ContextManager.historyTokens(lastAnswer));
    } else {
      final historyTokens = windowed
          .where((m) => m.id != userMsg.id)
          .fold<int>(0, (sum, m) => sum + ContextManager.historyTokens(m));
      uncachedTokens = systemTokens + historyTokens + userTokens;
    }
    // A thinking model reasons unless told not to, so "unset" means it will.
    final expectsThinking = think ?? (modelInfo?.supportsThinking == true);
    final waitEstimate = HardwareCalibrationService().estimateResponse(
      uncachedPromptTokens: uncachedTokens,
      modelName: modelName,
      expectsThinking: expectsThinking,
      modelLoaded: modelLoaded,
    );
    if (!hasPdf && waitEstimate.isTested && waitEstimate.waitSeconds >= 4) {
      final tokenStr = uncachedTokens >= 1000 ? '~${(uncachedTokens / 1000).toStringAsFixed(1)}k' : '$uncachedTokens';
      gen.statusMessage = modelLoaded
          ? I18n.evaluatingContext(tokenStr, I18n.approxDuration(waitEstimate.waitSeconds))
          : I18n.loadingModel(modelName);
      gen.statusTokens = modelLoaded ? uncachedTokens : null;
      gen.statusEtaSeconds = waitEstimate.waitSeconds;
      _sync(gen);
    } else if (!hasPdf && !modelLoaded) {
      gen.statusMessage = I18n.loadingModel(modelName);
      _sync(gen);
    }

    final rawStreamBuffer = StringBuffer();
    final stopwatch = Stopwatch()..start();
    int tokenEstimate = 0;
    // Exact generation counters from Ollama, summed over tool rounds.
    int evalCount = 0;
    int evalDurationNs = 0;

    // Only clear standalone attachments if no workspace is active (preserve workspace files across conversation)
    if (wsState.workspace == null && !isRegeneration) {
      wsNotifier.clearAttachments();
    }

    final List<Map<String, dynamic>> tools = effectiveWorkspace != null && modelInfo?.supportsTools != false
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
          think: think,
          tools: withTools && tools.isNotEmpty ? tools : null,
          onToolCall: (toolCall) {
            pendingToolCall = toolCall;
          },
          onDoneMetrics: (metrics) {
            final promptCount = metrics['prompt_eval_count'] as int? ?? 0;
            final promptDurationNs = metrics['prompt_eval_duration'] as int? ?? 0;
            final roundEvalCount = metrics['eval_count'] as int? ?? 0;
            final roundEvalDurationNs = metrics['eval_duration'] as int? ?? 0;
            evalCount += roundEvalCount;
            evalDurationNs += roundEvalDurationNs;

            if (promptDurationNs > 0 || roundEvalDurationNs > 0) {
              HardwareCalibrationService().recordMetrics(
                promptEvalCount: promptCount,
                promptEvalDurationNs: promptDurationNs,
                evalCount: roundEvalCount,
                evalDurationNs: roundEvalDurationNs,
                loadDurationNs: metrics['load_duration'] as int? ?? 0,
                modelName: modelName,
              );
            }
          },
        );

        gen.stream = stream.listen(
          (chunk) {
            if (!mounted) return;
            if (gen.statusMessage != null || gen.statusTokens != null) {
              gen.statusMessage = null;
              gen.statusTokens = null;
              gen.statusEtaSeconds = null;
              _sync(gen);
            }
            rawStreamBuffer.write(chunk);
            tokenEstimate++;

            gen.schedulePublish(_streamPublishInterval, () {
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

              final msgs = List<Message>.from(gen.messages);
              if (msgs.isNotEmpty && msgs.last.id == assistantMsgId) {
                msgs[msgs.length - 1] = currentAssistant;
              }
              gen.messages = msgs;
              _sync(gen);
            });
          },
          onError: (err) {
            gen.dropPending();
            if (!mounted) return;
            if (withTools && err.toString().contains('400')) {
              runStream(withTools: false);
              return;
            }
            gen.messages = gen.messages.where((m) => m.id != assistantMsgId).toList();
            _finish(gen, error: _describeError(err));
          },
          onDone: () async {
            // The message list is what the user sees and what gets finalized; apply the last chunks first.
            gen.flushPending();
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
                  gen.statusMessage = I18n.readingFile(reqPath);
                  _sync(gen);

                  final fullPath = await WorkspaceService.resolveInsideWorkspace(effectiveWorkspace.path, reqPath);
                  final file = fullPath == null
                      ? null
                      : await AttachedFile.fromPath(
                          fullPath,
                          workspaceRoot: effectiveWorkspace.path,
                          maxLines: 400,
                        );
                  // The user may have stopped the answer while the file was read.
                  if (!mounted || gen.cancelled) return;

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
              gen.messages = gen.messages.where((m) => m.id != assistantMsgId).toList();
              _finish(gen);
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
              // Prefer Ollama's own counters: the chunk count and wall clock are
              // only estimates, and the wall clock includes prompt evaluation.
              tokens: evalCount > 0 ? evalCount : tokenEstimate,
              generationDurationMs:
                  evalDurationNs > 0 ? (evalDurationNs / 1e6).round() : stopwatch.elapsedMilliseconds,
            );

            final finalMsgs = List<Message>.from(gen.messages);
            if (finalMsgs.isNotEmpty && finalMsgs.last.id == assistantMsgId) {
              finalMsgs[finalMsgs.length - 1] = finalizedMsg;
            }
            gen.messages = finalMsgs;

            await _db.saveMessage(finalizedMsg);
            if (!mounted) return;
            _finish(gen);

            // This prompt is now what Ollama has cached for the conversation.
            _cachedPrefixes[convId] = prefixKey;
            if (evalCount > 0) {
              unawaited(HardwareCalibrationService().recordOutput(
                modelName: modelName,
                tokens: evalCount,
                hadThinking: finalizedMsg.thinkContent != null,
              ));
            }

            // Auto-summarize title in background if it was the first user message
            final titleSource = stripAttachmentPrefix(userMsg.content);
            if (isFirstMessageInConv && titleSource.isNotEmpty) {
              try {
                final title = await TitleService.generateTitle(
                  [userMsg.copyWith(content: titleSource)],
                  modelOverride: modelName,
                  numCtx: ollamaNumCtx,
                  // A title needs no reasoning, and reasoning would end up in it.
                  think: modelInfo?.supportsThinking == true ? false : null,
                );
                if (title.isNotEmpty && title != 'New Chat' && title != 'Neuer Chat') {
                  await _ref.read(sidebarProvider.notifier).updateTitle(convId, title);
                }
              } catch (_) {
                // Title generation is non-critical background task
              }
            }

            await _compactHistory(
              conversationId: convId,
              modelName: modelName,
              history: [...rawHistory, finalizedMsg],
              budgetTokens: budget.historyTokens,
              previousSummary: previousSummary,
              numCtx: ollamaNumCtx,
              think: modelInfo?.supportsThinking == true ? false : null,
            );
          },
          cancelOnError: true,
        );
      } catch (err) {
        if (withTools && err.toString().contains('400')) {
          runStream(withTools: false);
        } else {
          gen.messages = gen.messages.where((m) => m.id != assistantMsgId).toList();
          _finish(gen, error: _describeError(err));
        }
      }
    }

    await runStream(withTools: true);
  }

  final Set<String> _compacting = {};

  /// Folds older turns into the conversation summary once the history has
  /// outgrown its budget. Runs after the answer is on screen, so the cost is
  /// paid while the user reads rather than before the next reply.
  Future<void> _compactHistory({
    required String conversationId,
    required String modelName,
    required List<Message> history,
    required int budgetTokens,
    required String? previousSummary,
    required int? numCtx,
    required bool? think,
  }) async {
    final cut = ContextManager.planCompaction(history: history, budgetTokens: budgetTokens);
    if (cut == 0 || !_compacting.add(conversationId)) return;

    try {
      final summary = await SummaryService.summarize(
        model: modelName,
        previousSummary: previousSummary,
        turns: history.sublist(0, cut),
        numCtx: numCtx,
        think: think,
      );
      if (summary != null) {
        await _db.updateConversationSummary(conversationId, summary, history[cut - 1].id);
      }
    } catch (_) {
      // Without a summary the sliding window still bounds the next prompt.
    } finally {
      _compacting.remove(conversationId);
    }
  }

  /// Stops the answer in the chat on screen. Answers in other chats keep running.
  void stopGeneration() {
    _interrupt(state.conversationId);
  }

  /// Cancels a generation whose conversation is being deleted; nothing is saved.
  void discardGeneration(String conversationId) {
    _interrupt(conversationId, keepPartial: false);
    _lastErrors.remove(conversationId);
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
    for (final gen in _generations.values) {
      gen.dropPending();
      gen.stream?.cancel();
    }
    _generations.clear();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
