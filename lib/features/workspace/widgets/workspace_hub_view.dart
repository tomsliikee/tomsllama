import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:intl/intl.dart';

import '../../../core/models/conversation.dart';
import '../../../core/models/workspace.dart';
import '../../../core/models/workspace_context_file.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/services/hardware_calibration_service.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../../core/widgets/persona_chip.dart';
import '../../models/controllers/model_controller.dart';
import '../controllers/workspace_hub_controller.dart';
import 'cute_llama_file_mascot.dart';
import '../../../core/widgets/cute_send_button.dart';

class WorkspaceHubView extends ConsumerStatefulWidget {
  final Workspace workspace;
  final List<WorkspaceContextFile> files;
  final List<Conversation> chats;
  final void Function(String prompt, String model, String persona) onStartChat;
  final ValueChanged<String> onOpenChat;
  final ValueChanged<String>? onDeleteChat;

  const WorkspaceHubView({
    super.key,
    required this.workspace,
    required this.files,
    required this.chats,
    required this.onStartChat,
    required this.onOpenChat,
    this.onDeleteChat,
  });

  @override
  ConsumerState<WorkspaceHubView> createState() => _WorkspaceHubViewState();
}

class _WorkspaceHubViewState extends ConsumerState<WorkspaceHubView> {
  late final TextEditingController _promptController;
  late final TextEditingController _inputController;
  late final FocusNode _inputFocusNode;
  bool _isInputFocused = false;
  bool _isDraggingOverContext = false;
  String _selectedPersona = 'Standard';
  Timer? _promptSaveTimer;
  late final WorkspaceListNotifier _workspaceList;

  @override
  void initState() {
    super.initState();
    _workspaceList = ref.read(workspaceListProvider.notifier);
    _promptController = TextEditingController(text: widget.workspace.prompt);
    _inputController = TextEditingController();
    _inputFocusNode = FocusNode();
    _inputFocusNode.addListener(() {
      if (mounted) setState(() => _isInputFocused = _inputFocusNode.hasFocus);
    });
    _inputFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _submit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void didUpdateWidget(WorkspaceHubView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a different workspace replaces the field. Syncing on every prompt
    // change would overwrite what is being typed with the last saved value.
    if (widget.workspace.id != oldWidget.workspace.id) {
      _flushPendingPrompt(oldWidget.workspace.id);
      _promptController.text = widget.workspace.prompt;
    }
  }

  /// Writes a not-yet-saved prompt edit for [workspaceId], which may no longer
  /// be the active workspace, so it goes through the id-addressed list notifier.
  void _flushPendingPrompt(String workspaceId) {
    if (_promptSaveTimer?.isActive != true) return;
    _promptSaveTimer!.cancel();
    final text = _promptController.text;
    Future.microtask(() => _workspaceList.updateWorkspacePrompt(workspaceId, text));
  }

  @override
  void dispose() {
    _flushPendingPrompt(widget.workspace.id);
    _promptController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _savePrompt() {
    _promptSaveTimer?.cancel();
    ref.read(activeWorkspaceProvider.notifier).updatePrompt(_promptController.text);
  }

  // Saving reloads the workspace list from the database, so do it once typing pauses.
  void _schedulePromptSave() {
    _promptSaveTimer?.cancel();
    _promptSaveTimer = Timer(const Duration(milliseconds: 500), _savePrompt);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'dart', 'py', 'js', 'ts', 'html', 'css', 'json', 'yaml', 'yml',
        'md', 'txt', 'pdf', 'xml', 'sql', 'sh', 'csv', 'rs', 'go', 'c', 'cpp',
      ],
    );
    if (result == null || result.files.isEmpty) return;

    final notifier = ref.read(activeWorkspaceProvider.notifier);
    for (final f in result.files) {
      if (f.path != null) {
        await notifier.addFileFromPath(f.path!);
      }
    }
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    final notifier = ref.read(activeWorkspaceProvider.notifier);
    for (final file in details.files) {
      await notifier.addFileFromPath(file.path);
    }
  }

  void _submit() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final modelState = ref.read(modelProvider);
    final selectedModel = modelState.selectedModel ??
        (modelState.models.isNotEmpty ? modelState.models.first.name : 'qwen2.5:3b');
    _inputController.clear();
    widget.onStartChat(text, selectedModel, _selectedPersona);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final modelState = ref.watch(modelProvider);
    final activeWsState = ref.watch(activeWorkspaceProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Darkened background for all passive cards in light & dark mode
    final Color cardBackground = isDark
        ? appColors.sidebar
        : Color.alphaBlend(appColors.textPrimary.withValues(alpha: 0.035), appColors.surface);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800.0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Workspace Header Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: cardBackground,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(
                          color: appColors.borderSubtle,
                          width: 1.0,
                        ),
                      ),
                      child: Icon(AppIcons.folderOpen, size: 22.0, color: appColors.textSecondary),
                    ),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.workspace.name,
                            style: AppTypography.display.copyWith(
                              fontFamily: AppTypography.serifFamily,
                              fontStyle: FontStyle.italic,
                              color: appColors.textPrimary,
                              fontSize: 30.0,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            I18n.workspaceHubSubtitle(
                              widget.chats.length,
                              widget.files.length,
                              activeWsState.totalEstimatedTokens,
                            ),
                            style: AppTypography.label.copyWith(
                              color: appColors.textSecondary,
                              fontSize: 12.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20.0),

                // 2. Workspace Prompt Box (Persistent Instructions) - Darkened & sans-serif font
                _buildPromptCard(appColors, cardBackground, isDark),

                const SizedBox(height: 16.0),

                // 3. Workspace Knowledge / Context Box (with Telemetry Footer)
                _buildContextFilesCard(appColors, cardBackground, isDark),

                const SizedBox(height: 26.0),

                // 4. Central Composer Input Field - Strongly Highlighted
                _buildComposerCard(
                  appColors,
                  modelState.selectedModel ??
                      (modelState.models.isNotEmpty ? modelState.models.first.name : 'qwen2.5:3b'),
                  isDark,
                ),

                const SizedBox(height: 32.0),

                // 5. Chats in this Workspace (with generous spacing below input)
                _buildWorkspaceChatsList(appColors, cardBackground, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromptCard(AppThemeExtension appColors, Color cardBackground, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: appColors.borderSubtle, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(AppIcons.modeThinking, size: 16.0, color: appColors.accent),
                  const SizedBox(width: 6.0),
                  Text(
                    I18n.workspacePromptTitle,
                    style: AppTypography.micro.copyWith(color: appColors.textSecondary),
                  ),
                ],
              ),
              InkWell(
                onTap: _savePrompt,
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: isDark ? appColors.surface : appColors.background,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: appColors.borderSubtle, width: 1.0),
                  ),
                  child: Text(
                    I18n.save,
                    style: AppTypography.label.copyWith(
                      color: appColors.textPrimary,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          TextField(
            controller: _promptController,
            maxLines: 4,
            minLines: 2,
            style: AppTypography.small.copyWith(
              color: appColors.textPrimary,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: I18n.workspacePromptHint,
              hintStyle: AppTypography.small.copyWith(
                color: appColors.textSecondary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => _schedulePromptSave(),
          ),
        ],
      ),
    );
  }

  Widget _buildContextFilesCard(AppThemeExtension appColors, Color cardBackground, bool isDark) {
    final totalFileTokens = widget.files.fold<int>(0, (sum, f) => sum + f.estimatedTokens);
    final modelState = ref.watch(modelProvider);
    final activeModel = modelState.selectedModel ?? (modelState.models.isNotEmpty ? modelState.models.first.name : null);
    final hwCalibration = ref.watch(hardwareCalibrationProvider);
    final fileEstimate = hwCalibration.estimatePrompt(
      tokens: totalFileTokens,
      mode: ChatExecutionMode.optimal,
      modelName: activeModel,
    );
    final tokenStr = totalFileTokens >= 1000
        ? '~${(totalFileTokens / 1000).toStringAsFixed(1)}k tok'
        : '$totalFileTokens tok';

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDraggingOverContext = true),
      onDragExited: (_) => setState(() => _isDraggingOverContext = false),
      onDragDone: (details) {
        setState(() => _isDraggingOverContext = false);
        _handleDrop(details);
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: _isDraggingOverContext ? appColors.accent : appColors.borderSubtle,
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: File Manager
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(AppIcons.knowledge, size: 16.0, color: appColors.accent),
                              const SizedBox(width: 6.0),
                              Text(
                                I18n.workspaceContextTitle,
                                style: AppTypography.micro.copyWith(color: appColors.textSecondary),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: _pickFiles,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: isDark ? appColors.surface : appColors.background,
                                borderRadius: BorderRadius.circular(AppRadii.card),
                                border: Border.all(color: appColors.borderSubtle, width: 1.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(AppIcons.add, size: 13.0, color: appColors.textPrimary),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    I18n.addFile,
                                    style: AppTypography.label.copyWith(
                                      color: appColors.textPrimary,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        I18n.workspaceDropFilesHint,
                        style: AppTypography.small.copyWith(
                          color: appColors.textSecondary,
                          fontSize: 14.0,
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      // Attached files pills
                      if (widget.files.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            I18n.workspaceNoFilesHint,
                            style: AppTypography.small.copyWith(
                              color: appColors.textSecondary.withValues(alpha: 0.8),
                              fontSize: 14.0,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: widget.files.map((file) {
                            final isPdf = file.extension == '.pdf';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: isDark ? appColors.surface : appColors.background,
                                borderRadius: BorderRadius.circular(AppRadii.card),
                                border: Border.all(color: appColors.borderSubtle, width: 1.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPdf ? AppIcons.pdf : AppIcons.file,
                                    size: 13.0,
                                    color: isPdf ? appColors.accent : appColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6.0),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 160.0),
                                    child: Text(
                                      file.fileName,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.code.copyWith(
                                        color: appColors.textPrimary,
                                        fontSize: 12.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6.0),
                                  Text(
                                    '~${file.estimatedTokens}t',
                                    style: AppTypography.code.copyWith(
                                      color: appColors.textSecondary,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6.0),
                                  InkWell(
                                    onTap: () => ref.read(activeWorkspaceProvider.notifier).removeFile(file.id),
                                    borderRadius: BorderRadius.circular(AppRadii.control),
                                    child: Icon(AppIcons.close, size: 13.0, color: appColors.textSecondary),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 14.0),

                // Right Column: Cute Animated Llama Mascot
                const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: CuteLlamaFileMascot(size: 80.0),
                ),
              ],
            ),

            // Telemetry Footer: exact telemetry (token cost, speed, duration) as footer instead of pill
            Container(
              height: 1.0,
              margin: const EdgeInsets.only(top: 14.0, bottom: 10.0),
              color: appColors.borderSubtle,
            ),
            Row(
              children: [
                Icon(
                  AppIcons.speed,
                  size: 13.0,
                  color: appColors.textSecondary,
                ),
                const SizedBox(width: 6.0),
                Text(
                  !fileEstimate.isTested
                      ? '${I18n.totalLabel}: $tokenStr'
                      : '${I18n.totalLabel}: $tokenStr • +${fileEstimate.durationDisplay}',
                  style: AppTypography.code.copyWith(
                    fontSize: 10.5,
                    color: appColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerCard(AppThemeExtension appColors, String activeModel, bool isDark) {
    final canSend = _inputController.text.trim().isNotEmpty;
    final Color composerBg = isDark
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.04), appColors.surface)
        : appColors.surface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: composerBg,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        // Same rule as the chat composer: one hairline, accent only while focused.
        border: Border.all(
          color: _isInputFocused ? appColors.accent.withValues(alpha: 0.7) : appColors.border,
          width: 1.0,
        ),
        boxShadow: AppElevation.floating(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _inputController,
            focusNode: _inputFocusNode,
            maxLines: 8,
            minLines: 2,
            textInputAction: TextInputAction.send,
            style: AppTypography.body.copyWith(
              color: appColors.textPrimary,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: I18n.askInWorkspace,
              hintStyle: AppTypography.body.copyWith(
                color: appColors.textSecondary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
            ),
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Chips for model and role
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 6.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                        decoration: BoxDecoration(
                          color: isDark ? appColors.surface : appColors.background,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(color: appColors.borderSubtle, width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(AppIcons.model, size: 12.5, color: appColors.textSecondary),
                            const SizedBox(width: 4.0),
                            Text(
                              activeModel,
                              style: AppTypography.code.copyWith(
                                fontSize: 12.0,
                                color: appColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PersonaChip(
                        personaName: _selectedPersona,
                        onTap: () {},
                        onSelectPersona: (p) => setState(() => _selectedPersona = p),
                      ),
                    ],
                  ),
                ),
              ),

              // Circular Send Button with organic Cloud morph & Cute Llama
              CuteSendButton(
                isGenerating: false,
                hasText: canSend,
                onTap: canSend ? _submit : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceChatsList(AppThemeExtension appColors, Color cardBackground, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              I18n.workspaceChatsTitle,
              style: AppTypography.micro.copyWith(color: appColors.textSecondary),
            ),
            Text(
              I18n.workspaceConversationsCount(widget.chats.length),
              style: AppTypography.label.copyWith(
                color: appColors.textSecondary,
                fontSize: 12.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),

        if (widget.chats.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: appColors.borderSubtle, width: 1.0),
            ),
            child: Text(
              I18n.workspaceNoChatsHint,
              textAlign: TextAlign.center,
              style: AppTypography.label.copyWith(
                color: appColors.textSecondary,
                fontSize: 12.0,
                height: 1.4,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8.0),
            itemBuilder: (context, index) {
              final chat = widget.chats[index];
              final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(chat.updatedAt);

              return InkWell(
                onTap: () => widget.onOpenChat(chat.id),
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: cardBackground,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: appColors.borderSubtle, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      Icon(AppIcons.chats, size: 16.0, color: appColors.textSecondary),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.small.copyWith(
                                color: appColors.textPrimary,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              '$dateStr · ${I18n.roleLabel}${chat.persona}',
                              style: AppTypography.telemetry.copyWith(color: appColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onDeleteChat != null)
                        AppIconButton(
                          icon: AppIcons.close,
                          size: 14.0,
                          tooltip: I18n.deleteChatConfirm,
                          hoverColor: appColors.accent,
                          onTap: () => widget.onDeleteChat!(chat.id),
                        ),
                      const SizedBox(width: 4.0),
                      Icon(AppIcons.caretRight, size: 16.0, color: appColors.textSecondary),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
