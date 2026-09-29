import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:intl/intl.dart';

import '../../../core/models/conversation.dart';
import '../../../core/models/workspace.dart';
import '../../../core/models/workspace_context_file.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';
import '../../models/controllers/model_controller.dart';
import '../controllers/workspace_hub_controller.dart';
import 'cute_llama_file_mascot.dart';

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
  bool _isDraggingOverContext = false;
  String _selectedPersona = 'Standard';

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.workspace.prompt);
    _inputController = TextEditingController();
  }

  @override
  void didUpdateWidget(WorkspaceHubView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.workspace.id != oldWidget.workspace.id ||
        widget.workspace.prompt != _promptController.text) {
      _promptController.text = widget.workspace.prompt;
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _savePrompt() {
    ref.read(activeWorkspaceProvider.notifier).updatePrompt(_promptController.text);
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
                        color: appColors.accentSubtle,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: appColors.accent.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      child: Icon(Icons.folder_special_outlined, size: 22.0, color: appColors.accent),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.workspace.name,
                            style: AppTypography.headline.copyWith(
                              color: appColors.textPrimary,
                              fontSize: 22.0,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            'Workspace Hub • ${widget.chats.length} Chats • ${widget.files.length} Kontext-Dateien (~${activeWsState.totalEstimatedTokens} Tokens)',
                            style: AppTypography.uiControl.copyWith(
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

                // 2. Workspace Prompt Box (Persistent Instructions)
                _buildPromptCard(appColors),

                const SizedBox(height: 16.0),

                // 3. Workspace Knowledge / Context Box (with Cute Animated Llama Mascot)
                _buildContextFilesCard(appColors),

                const SizedBox(height: 26.0),

                // 4. Central Composer Input Field
                _buildComposerCard(
                  appColors,
                  modelState.selectedModel ??
                      (modelState.models.isNotEmpty ? modelState.models.first.name : 'qwen2.5:3b'),
                ),

                const SizedBox(height: 32.0),

                // 5. Chats in this Workspace (with generous spacing below input)
                _buildWorkspaceChatsList(appColors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromptCard(AppThemeExtension appColors) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(16.0),
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
                  Icon(Icons.psychology_outlined, size: 16.0, color: appColors.accent),
                  const SizedBox(width: 6.0),
                  Text(
                    I18n.workspacePromptTitle,
                    style: AppTypography.code.copyWith(
                      color: appColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _savePrompt,
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: appColors.accentSubtle,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: appColors.accent.withValues(alpha: 0.25), width: 1.0),
                  ),
                  child: Text(
                    'Speichern',
                    style: AppTypography.uiControl.copyWith(
                      color: appColors.accent,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
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
            style: AppTypography.body.copyWith(
              color: appColors.textPrimary,
              fontSize: 13.5,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: 'Gib hier dauerhafte Instruktionen, Coding-Regeln oder Rollenanweisungen für diesen Workspace ein (z. B. "Du bist Principal Engineer, antworte präzise auf Deutsch")...',
              hintStyle: AppTypography.body.copyWith(color: appColors.textSecondary.withValues(alpha: 0.6), fontSize: 13.0),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => _savePrompt(),
          ),
        ],
      ),
    );
  }

  Widget _buildContextFilesCard(AppThemeExtension appColors) {
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
          color: appColors.surface,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: _isDraggingOverContext ? appColors.accent : appColors.borderSubtle,
            width: 1.0,
          ),
        ),
        child: Row(
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
                          Icon(Icons.inventory_2_outlined, size: 16.0, color: appColors.accent),
                          const SizedBox(width: 6.0),
                          Text(
                            I18n.workspaceContextTitle,
                            style: AppTypography.code.copyWith(
                              color: appColors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: _pickFiles,
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: appColors.accentSubtle,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: appColors.accent.withValues(alpha: 0.25), width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 13.0, color: appColors.accent),
                              const SizedBox(width: 3.0),
                              Text(
                                'Datei hinzufügen',
                                style: AppTypography.uiControl.copyWith(
                                  color: appColors.accent,
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
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
                    'Dateien hier ablegen. Sie werden in jedem Chat dieses Workspaces automatisch geladen.',
                    style: AppTypography.uiControl.copyWith(
                      color: appColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // Attached files pills
                  if (widget.files.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Noch keine Dateien hinterlegt. Ziehe Dokumente oder Code hierher.',
                        style: AppTypography.uiControl.copyWith(
                          color: appColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12.0,
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
                          padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
                          decoration: BoxDecoration(
                            color: appColors.hover,
                            borderRadius: BorderRadius.circular(10.0),
                            border: Border.all(color: appColors.borderSubtle, width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPdf ? Icons.picture_as_pdf_outlined : Icons.description_outlined,
                                size: 13.0,
                                color: isPdf ? Colors.redAccent.shade200 : appColors.accent,
                              ),
                              const SizedBox(width: 5.0),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160.0),
                                child: Text(
                                  file.fileName,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.code.copyWith(
                                    color: appColors.textPrimary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                '~${file.estimatedTokens}t',
                                style: AppTypography.code.copyWith(
                                  color: appColors.textSecondary,
                                  fontSize: 10.0,
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              InkWell(
                                onTap: () => ref.read(activeWorkspaceProvider.notifier).removeFile(file.id),
                                borderRadius: BorderRadius.circular(4.0),
                                child: Icon(Icons.close, size: 12.0, color: appColors.textSecondary),
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

            // Right Column: Cute Animated Llama Mascot cycling files every 3s!
            const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: CuteLlamaFileMascot(size: 80.0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerCard(AppThemeExtension appColors, String activeModel) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: appColors.borderSubtle, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _inputController,
            maxLines: 3,
            minLines: 1,
            style: AppTypography.body.copyWith(
              color: appColors.textPrimary,
              fontSize: 14.0,
            ),
            decoration: InputDecoration(
              hintText: I18n.askInWorkspace,
              hintStyle: AppTypography.body.copyWith(
                color: appColors.textSecondary.withValues(alpha: 0.65),
                fontSize: 13.5,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Chips for model and role
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: appColors.hover,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: appColors.borderSubtle, width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 12.0, color: appColors.accent),
                        const SizedBox(width: 4.0),
                        Text(
                          activeModel,
                          style: AppTypography.code.copyWith(
                            fontSize: 11.0,
                            color: appColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  PopupMenuButton<String>(
                    initialValue: _selectedPersona,
                    tooltip: 'Rolle wählen',
                    onSelected: (p) => setState(() => _selectedPersona = p),
                    itemBuilder: (_) => [
                      'Standard', 'Coder', 'Architect', 'Creative', 'Academic', 'Writing',
                    ].map((p) => PopupMenuItem(value: p, child: Text(p))).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: appColors.hover,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: appColors.borderSubtle, width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline, size: 12.0, color: appColors.textSecondary),
                          const SizedBox(width: 4.0),
                          Text(
                            _selectedPersona,
                            style: AppTypography.uiControl.copyWith(
                              fontSize: 11.0,
                              color: appColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Send button
              InkWell(
                onTap: _submit,
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: appColors.accent,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        I18n.send,
                        style: AppTypography.uiControl.copyWith(
                          color: Colors.white,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      const Icon(Icons.arrow_upward, size: 13.0, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceChatsList(AppThemeExtension appColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              I18n.workspaceChatsTitle,
              style: AppTypography.code.copyWith(
                color: appColors.textSecondary,
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${widget.chats.length} Konversationen',
              style: AppTypography.uiControl.copyWith(
                color: appColors.textSecondary,
                fontSize: 11.5,
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
              color: appColors.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: appColors.borderSubtle, width: 1.0),
            ),
            child: Text(
              'Noch keine Chats in diesem Workspace vorhanden.\nStelle oben eine Frage, um die erste Unterhaltung zu starten.',
              textAlign: TextAlign.center,
              style: AppTypography.uiControl.copyWith(
                color: appColors.textSecondary,
                fontSize: 12.5,
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
                borderRadius: BorderRadius.circular(14.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(color: appColors.borderSubtle, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 16.0, color: appColors.accent),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.uiControl.copyWith(
                                color: appColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              '$dateStr • Rolle: ${chat.persona}',
                              style: AppTypography.uiControl.copyWith(
                                color: appColors.textSecondary,
                                fontSize: 11.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onDeleteChat != null)
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 14.0, color: appColors.textSecondary),
                          onPressed: () => widget.onDeleteChat!(chat.id),
                          tooltip: I18n.deleteChatConfirm,
                          splashRadius: 16.0,
                        ),
                      Icon(Icons.chevron_right, size: 16.0, color: appColors.textSecondary),
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
