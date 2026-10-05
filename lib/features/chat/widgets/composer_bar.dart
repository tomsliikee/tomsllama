import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/ollama_model.dart';
import '../../../core/models/workspace_info.dart';
import '../../../core/models/attached_file.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/frosted_glass.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/services/hardware_calibration_service.dart';
import '../../../core/services/settings_service.dart';
import '../controllers/chat_controller.dart';
import '../controllers/workspace_controller.dart';
import 'persona_chip.dart';
import 'cute_send_button.dart';
import 'composer_shelf.dart';

class ComposerBar extends ConsumerStatefulWidget {
  final bool isGenerating;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final String activePersonaName;
  final VoidCallback onPersonaTap;
  final ValueChanged<String>? onSelectPersona;
  final String? modelName;
  final List<OllamaModel> models;
  final String? selectedModel;
  final ValueChanged<String?>? onModelChanged;
  final VoidCallback? onManageModels;
  final ChatExecutionMode mode;
  final ValueChanged<ChatExecutionMode>? onModeChanged;

  const ComposerBar({
    super.key,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
    required this.activePersonaName,
    required this.onPersonaTap,
    this.onSelectPersona,
    this.modelName,
    this.models = const [],
    this.selectedModel,
    this.onModelChanged,
    this.onManageModels,
    this.mode = ChatExecutionMode.optimal,
    this.onModeChanged,
  });

  @override
  ConsumerState<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends ConsumerState<ComposerBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<CuteSendButtonState> _sendButtonKey = GlobalKey<CuteSendButtonState>();
  bool _hasText = false;
  bool _isFocused = false;
  bool _isShelfExpanded = false;

  // Autocomplete '@' mention state
  bool _showAtPopup = false;
  int _atStartIndex = -1;
  List<String> _atMatches = [];
  int _atSelectedIndex = 0;

  // Prompt history navigation state (ArrowUp / ArrowDown)
  final List<String> _localPromptHistory = [];
  int _historyIndex = -1;
  String _draftText = '';
  bool _isNavigatingHistory = false;

  List<String> _getAllPrompts() {
    final chatMessages = ref.read(chatProvider).messages;
    final prompts = <String>[];
    for (final m in chatMessages) {
      if (m.role == 'user') {
        String clean = m.content;
        if (clean.contains('#### User Request:')) {
          final parts = clean.split(RegExp(r'#### User Request:\s*'));
          clean = parts.last.trim();
        } else if (clean.startsWith('[attached:')) {
          final endIdx = clean.indexOf(']');
          if (endIdx != -1) {
            clean = clean.substring(endIdx + 1).trim();
          }
        }
        if (clean.isNotEmpty && (prompts.isEmpty || prompts.last != clean)) {
          prompts.add(clean);
        }
      }
    }
    for (final p in _localPromptHistory) {
      if (p.isNotEmpty && (prompts.isEmpty || prompts.last != p)) {
        prompts.add(p);
      }
    }
    return prompts;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _focusNode.onKeyEvent = (node, event) => _onKeyEvent(event);
    SettingsService().loadComposerShelfExpanded().then((expanded) {
      if (mounted && expanded) {
        setState(() => _isShelfExpanded = true);
      }
    });
  }

  void _toggleShelf() {
    setState(() {
      _isShelfExpanded = !_isShelfExpanded;
    });
    SettingsService().saveComposerShelfExpanded(_isShelfExpanded);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (_hasText != hasText && mounted) {
      setState(() => _hasText = hasText);
    }
    if (!_isNavigatingHistory && _historyIndex != -1) {
      _historyIndex = -1;
    }
    _checkAtMention();
  }

  void _onFocusChanged() {
    if (_isFocused != _focusNode.hasFocus && mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
      if (!_focusNode.hasFocus && _showAtPopup) {
        setState(() => _showAtPopup = false);
      }
    }
  }

  void _checkAtMention() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid || selection.start != selection.end) {
      if (_showAtPopup) setState(() => _showAtPopup = false);
      return;
    }

    final cursorPos = selection.start;
    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex != -1) {
      final query = textBeforeCursor.substring(atIndex + 1);
      // Valid mention query: no spaces, no newlines
      if (!query.contains(' ') && !query.contains('\n')) {
        final workspace = ref.read(workspaceProvider).workspace;
        if (workspace != null && workspace.files.isNotEmpty) {
          final matches = workspace.files.where((f) {
            return f.toLowerCase().contains(query.toLowerCase());
          }).take(8).toList();

          if (matches.isNotEmpty) {
            setState(() {
              _atStartIndex = atIndex;
              _atMatches = matches;
              _showAtPopup = true;
              _atSelectedIndex = 0;
            });
            return;
          }
        }
      }
    }

    if (_showAtPopup) {
      setState(() => _showAtPopup = false);
    }
  }

  void _selectAtMatch(String relPath) {
    final ws = ref.read(workspaceProvider).workspace;
    if (ws == null) return;
    final fullPath = p.join(ws.path, relPath);
    ref.read(workspaceProvider.notifier).attachFiles([fullPath]);

    // Clean up '@query' from input text
    final text = _controller.text;
    if (_atStartIndex >= 0 && _atStartIndex < text.length) {
      final textBeforeAt = text.substring(0, _atStartIndex);
      final cursorPos = _controller.selection.isValid ? _controller.selection.start : text.length;
      final textAfterCursor = cursorPos <= text.length ? text.substring(cursorPos) : '';
      _controller.text = '$textBeforeAt$textAfterCursor';
      _controller.selection = TextSelection.collapsed(offset: _atStartIndex);
    }

    setState(() {
      _showAtPopup = false;
      _atMatches = [];
    });
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    final hasAttached = ref.read(workspaceProvider).attachedFiles.isNotEmpty;
    if (text.isEmpty && !hasAttached) return;

    if (text.isNotEmpty) {
      if (_localPromptHistory.isEmpty || _localPromptHistory.last != text) {
        _localPromptHistory.add(text);
      }
    }
    _historyIndex = -1;
    _draftText = '';

    _sendButtonKey.currentState?.triggerCuteAnimation();
    widget.onSend(text);
    _controller.clear();
    setState(() {
      _hasText = false;
      _showAtPopup = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (_showAtPopup && _atMatches.isNotEmpty) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            _atSelectedIndex = (_atSelectedIndex + 1) % _atMatches.length;
          });
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            _atSelectedIndex = (_atSelectedIndex - 1 + _atMatches.length) % _atMatches.length;
          });
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.tab || event.logicalKey == LogicalKeyboardKey.enter) {
          _selectAtMatch(_atMatches[_atSelectedIndex]);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() => _showAtPopup = false);
          return KeyEventResult.handled;
        }
      }
    }

    if (event is KeyDownEvent) {
      // 1. Enter to submit
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                               HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
        if (!isShiftPressed) {
          _handleSend();
          return KeyEventResult.handled;
        }
      }

      // 2. Arrow Up to cycle to older prompts
      if (event.logicalKey == LogicalKeyboardKey.arrowUp && !_showAtPopup) {
        final text = _controller.text;
        final cursorPos = _controller.selection.isValid ? _controller.selection.start : 0;
        final isFirstLine = !text.substring(0, cursorPos).contains('\n');

        if (isFirstLine) {
          final prompts = _getAllPrompts();
          if (prompts.isNotEmpty) {
            if (_historyIndex == -1) {
              _draftText = text;
              _historyIndex = prompts.length - 1;
            } else if (_historyIndex > 0) {
              _historyIndex--;
            }
            final targetPrompt = prompts[_historyIndex];
            _isNavigatingHistory = true;
            _controller.text = targetPrompt;
            _controller.selection = TextSelection.collapsed(offset: targetPrompt.length);
            _isNavigatingHistory = false;
            return KeyEventResult.handled;
          }
        }
      }

      // 3. Arrow Down to cycle to newer prompts / restore draft
      if (event.logicalKey == LogicalKeyboardKey.arrowDown && !_showAtPopup) {
        if (_historyIndex != -1) {
          final prompts = _getAllPrompts();
          if (_historyIndex < prompts.length - 1) {
            _historyIndex++;
            final targetPrompt = prompts[_historyIndex];
            _isNavigatingHistory = true;
            _controller.text = targetPrompt;
            _controller.selection = TextSelection.collapsed(offset: targetPrompt.length);
            _isNavigatingHistory = false;
            return KeyEventResult.handled;
          } else if (_historyIndex >= prompts.length - 1) {
            _historyIndex = -1;
            _isNavigatingHistory = true;
            _controller.text = _draftText;
            _controller.selection = TextSelection.collapsed(offset: _draftText.length);
            _isNavigatingHistory = false;
            return KeyEventResult.handled;
          }
        }
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _pickWorkspace() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null && mounted) {
      await ref.read(workspaceProvider.notifier).setWorkspace(result);
    }
  }

  Future<void> _pickFolderFiles() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null && mounted) {
      await ref.read(workspaceProvider.notifier).attachFolderFiles(result);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result != null && mounted) {
      final paths = result.paths.whereType<String>().toList();
      await ref.read(workspaceProvider.notifier).attachFiles(paths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final workspaceState = ref.watch(workspaceProvider);
    final canSend = _hasText || workspaceState.attachedFiles.isNotEmpty;
    final activeModel = widget.selectedModel ?? widget.modelName;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Extended Shelf seamlessly connecting to the top edge
              ComposerShelf(
                isExpanded: _isShelfExpanded,
                workspace: workspaceState.workspace,
                attachedFiles: workspaceState.attachedFiles,
                selectedModel: activeModel,
                mode: widget.mode,
                onToggle: _toggleShelf,
              ),

              FrostedGlass(
                padding: const EdgeInsets.all(12.0),
                borderRadius: _isShelfExpanded
                    ? const BorderRadius.vertical(bottom: Radius.circular(20.0))
                    : BorderRadius.circular(20.0),
                borderColor: _isFocused ? appColors.accent : appColors.borderSubtle,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: isDark ? 16.0 : 12.0,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.20)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4.0,
                    offset: const Offset(0, 1),
                  ),
                  if (_isFocused)
                    BoxShadow(
                      color: appColors.accentSubtle,
                      spreadRadius: 2.0,
                      blurRadius: 0.0,
                    ),
                ],
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Active Workspace & Attached File Pills
                  if (workspaceState.workspace != null || workspaceState.attachedFiles.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final hwCalibration = ref.watch(hardwareCalibrationProvider);
                        final activeModel = widget.selectedModel ?? widget.modelName;
                        final isSingleFile = workspaceState.attachedFiles.length == 1;
                        final singleFileEstimate = isSingleFile
                            ? hwCalibration.estimatePrompt(
                                tokens: workspaceState.attachedFiles.first.estimatedTokens,
                                mode: widget.mode,
                                modelName: activeModel,
                              )
                            : null;
                        final totalEstimate = workspaceState.attachedFiles.length > 1
                            ? hwCalibration.estimatePrompt(
                                tokens: workspaceState.totalAttachedTokens,
                                mode: widget.mode,
                                modelName: activeModel,
                              )
                            : null;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Wrap(
                            spacing: 6.0,
                            runSpacing: 6.0,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (workspaceState.workspace != null)
                                _WorkspacePill(
                                  workspace: workspaceState.workspace!,
                                  onRemove: () => ref.read(workspaceProvider.notifier).clearWorkspace(),
                                ),
                              for (final file in workspaceState.attachedFiles)
                                _AttachedFilePill(
                                  file: file,
                                  estimate: isSingleFile ? singleFileEstimate : null,
                                  onRemove: () => ref.read(workspaceProvider.notifier).removeAttachedFile(file.path),
                                ),
                              if (workspaceState.attachedFiles.length > 1 && totalEstimate != null)
                                _AttachedFilesSummaryPill(
                                  totalTokens: workspaceState.totalAttachedTokens,
                                  estimate: totalEstimate,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  // Autocomplete popup for '@' mention
                  if (_showAtPopup && _atMatches.isNotEmpty) ...[
                    FrostedGlass(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      borderRadius: BorderRadius.circular(12.0),
                      borderColor: appColors.borderSubtle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
                          blurRadius: 10.0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                            child: Row(
                              children: [
                                Icon(Icons.alternate_email_rounded, size: 12.0, color: appColors.accent),
                                const SizedBox(width: 5.0),
                                Text(
                                  workspaceState.workspace != null
                                      ? 'Workspace: ${workspaceState.workspace!.name}'
                                      : I18n.workspaceFilesPrefix,
                                  style: AppTypography.uiControl.copyWith(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w600,
                                    color: appColors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  I18n.atMentionNavigationHint,
                                  style: AppTypography.code.copyWith(
                                    fontSize: 9.5,
                                    color: appColors.textSecondary.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(height: 1.0, color: appColors.borderSubtle),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 180.0),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              itemCount: _atMatches.length,
                              itemBuilder: (context, idx) {
                                final match = _atMatches[idx];
                                final isSelected = idx == _atSelectedIndex;
                                return InkWell(
                                  onTap: () => _selectAtMatch(match),
                                  borderRadius: BorderRadius.circular(6.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                                    color: isSelected ? appColors.accentSubtle : Colors.transparent,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.description_outlined,
                                          size: 13.0,
                                          color: isSelected ? appColors.accent : appColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6.0),
                                        Expanded(
                                          child: Text(
                                            match,
                                            style: AppTypography.code.copyWith(
                                              fontSize: 12.0,
                                              color: isSelected ? appColors.accent : appColors.textPrimary,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Text Input with Shelf Toggle Button (^ chevron)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: 12,
                          minLines: 2,
                          textInputAction: TextInputAction.newline,
                          style: AppTypography.uiControl.copyWith(
                            color: appColors.textPrimary,
                            fontSize: 15.0,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: I18n.composerPlaceholder(
                              activeModel ??
                                  (widget.models.isNotEmpty ? widget.models.first.name : 'qwen2.5:3b'),
                            ),
                            hintStyle: AppTypography.uiControl.copyWith(
                              color: appColors.textSecondary.withValues(alpha: 0.6),
                              fontSize: 14.0,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      ShelfToggleButton(
                        isExpanded: _isShelfExpanded,
                        onTap: _toggleShelf,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 10.0),

                  // Bottom Bar: Chips with Wrap and Send Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Chips wrapped to prevent pixel overflow on resize or canvas split
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Wrap(
                            spacing: 6.0,
                            runSpacing: 6.0,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              PersonaChip(
                                personaName: widget.activePersonaName,
                                onTap: widget.onPersonaTap,
                                onSelectPersona: widget.onSelectPersona,
                              ),
                              if (widget.models.isNotEmpty || widget.selectedModel != null)
                                _ModelChip(
                                  models: widget.models,
                                  selectedModel: widget.selectedModel,
                                  onModelChanged: widget.onModelChanged,
                                  onManageModels: widget.onManageModels,
                                ),
                              if (widget.onModeChanged != null)
                                _ModeChip(
                                  mode: widget.mode,
                                  onModeChanged: widget.onModeChanged,
                                ),
                              _AttachChip(
                                onPickWorkspace: _pickWorkspace,
                                onAttachFolder: _pickFolderFiles,
                                onPickFiles: _pickFiles,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Circular Send Button with organic Cloud morph & Cute Llama
                      CuteSendButton(
                        key: _sendButtonKey,
                        isGenerating: widget.isGenerating,
                        hasText: canSend,
                        onTap: widget.isGenerating ? widget.onStop : (canSend ? _handleSend : null),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _WorkspacePill extends StatelessWidget {
  final WorkspaceInfo workspace;
  final VoidCallback onRemove;

  const _WorkspacePill({
    required this.workspace,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: appColors.hover,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: appColors.accent.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, size: 13.5, color: appColors.accent),
          const SizedBox(width: 5.0),
          Text(
            workspace.name,
            style: AppTypography.uiControl.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: appColors.textPrimary,
            ),
          ),
          if (workspace.gitBranch != null) ...[
            const SizedBox(width: 6.0),
            Container(
              width: 1.0,
              height: 10.0,
              color: appColors.borderSubtle,
            ),
            const SizedBox(width: 6.0),
            Icon(Icons.call_split_rounded, size: 12.5, color: appColors.textSecondary),
            const SizedBox(width: 3.0),
            Text(
              workspace.gitBranch!,
              style: AppTypography.code.copyWith(
                fontSize: 11.0,
                fontWeight: FontWeight.w500,
                color: appColors.accent,
              ),
            ),
          ],
          const SizedBox(width: 5.0),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(Icons.close_rounded, size: 12.0, color: appColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachedFilePill extends StatelessWidget {
  final AttachedFile file;
  final HardwareEstimate? estimate;
  final VoidCallback onRemove;

  const _AttachedFilePill({
    required this.file,
    this.estimate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: appColors.hover,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: appColors.borderSubtle,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            file.extension == '.pdf' ? Icons.picture_as_pdf_outlined : Icons.description_outlined,
            size: 13.0,
            color: file.extension == '.pdf'
                ? Colors.redAccent.shade200
                : appColors.textSecondary,
          ),
          const SizedBox(width: 5.0),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160.0),
            child: Text(
              file.name,
              style: AppTypography.uiControl.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: appColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4.0),
          Text(
            file.estimatedTokens >= 1000
                ? '~${(file.estimatedTokens / 1000).toStringAsFixed(1)}k tok'
                : '${file.estimatedTokens} tok',
            style: AppTypography.code.copyWith(
              fontSize: 10.0,
              color: appColors.textSecondary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w400,
            ),
          ),
          if (estimate != null) ...[
            const SizedBox(width: 4.0),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240.0),
              child: Text(
                !estimate!.isTested
                    ? '• ${estimate!.speedDisplay}'
                    : '• ${estimate!.speedDisplay} • ${estimate!.durationDisplay}',
                style: AppTypography.code.copyWith(
                  fontSize: 10.0,
                  color: appColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
          const SizedBox(width: 4.0),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(Icons.close_rounded, size: 12.0, color: appColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachedFilesSummaryPill extends StatelessWidget {
  final int totalTokens;
  final HardwareEstimate estimate;

  const _AttachedFilesSummaryPill({
    required this.totalTokens,
    required this.estimate,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final tokenStr = totalTokens >= 1000
        ? '~${(totalTokens / 1000).toStringAsFixed(1)}k tok'
        : '$totalTokens tok';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: appColors.hover,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: appColors.borderSubtle,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.speed_rounded,
            size: 13.0,
            color: appColors.textSecondary,
          ),
          const SizedBox(width: 5.0),
          Text(
            !estimate.isTested
                ? '${I18n.totalLabel}: $tokenStr • ${estimate.speedDisplay}'
                : '${I18n.totalLabel}: $tokenStr • ${estimate.speedDisplay} • ${estimate.durationDisplay}',
            style: AppTypography.code.copyWith(
              fontSize: 10.0,
              color: appColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachChip extends StatefulWidget {
  final VoidCallback onPickWorkspace;
  final VoidCallback onAttachFolder;
  final VoidCallback onPickFiles;

  const _AttachChip({
    required this.onPickWorkspace,
    required this.onAttachFolder,
    required this.onPickFiles,
  });

  @override
  State<_AttachChip> createState() => _AttachChipState();
}

class _AttachChipState extends State<_AttachChip> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isOpen = false;

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  OverlayEntry _createOverlayEntry() {
    final appColors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeMenu,
            ),
          ),
          Positioned(
            width: 210,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topCenter,
              followerAnchor: Alignment.bottomCenter,
              offset: const Offset(0, -6),
              child: Material(
                color: Colors.transparent,
                child: FrostedGlass(
                  borderRadius: BorderRadius.circular(14.0),
                  borderColor: appColors.borderSubtle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 12.0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          _closeMenu();
                          widget.onPickWorkspace();
                        },
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14.0)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 9.0),
                          child: Row(
                            children: [
                              Icon(Icons.folder_outlined, size: 14.0, color: appColors.accent),
                              const SizedBox(width: 8.0),
                              Text(
                                I18n.openProjectWorkspace,
                                style: AppTypography.uiControl.copyWith(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                  color: appColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(height: 1.0, color: appColors.borderSubtle),
                      InkWell(
                        onTap: () {
                          _closeMenu();
                          widget.onAttachFolder();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 9.0),
                          child: Row(
                            children: [
                              Icon(Icons.snippet_folder_outlined, size: 14.0, color: appColors.accent),
                              const SizedBox(width: 8.0),
                              Text(
                                I18n.attachFolderFiles,
                                style: AppTypography.uiControl.copyWith(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                  color: appColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(height: 1.0, color: appColors.borderSubtle),
                      InkWell(
                        onTap: () {
                          _closeMenu();
                          widget.onPickFiles();
                        },
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14.0)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 9.0),
                          child: Row(
                            children: [
                              Icon(Icons.description_outlined, size: 14.0, color: appColors.accent),
                              const SizedBox(width: 8.0),
                              Text(
                                I18n.attachFiles,
                                style: AppTypography.uiControl.copyWith(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                  color: appColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleMenu,
          borderRadius: BorderRadius.circular(16.0),
          child: Container(
            height: 28.0,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: _isOpen ? appColors.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: _isOpen ? appColors.accent : appColors.borderSubtle,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.attach_file_rounded,
                  size: 14.0,
                  color: _isOpen ? appColors.accent : appColors.textSecondary,
                ),
                const SizedBox(width: 4.0),
                Text(
                  I18n.attach,
                  style: AppTypography.uiControl.copyWith(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: _isOpen ? appColors.accent : appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelChip extends StatefulWidget {
  final List<OllamaModel> models;
  final String? selectedModel;
  final ValueChanged<String?>? onModelChanged;
  final VoidCallback? onManageModels;

  const _ModelChip({
    required this.models,
    required this.selectedModel,
    this.onModelChanged,
    this.onManageModels,
  });

  @override
  State<_ModelChip> createState() => _ModelChipState();
}

class _ModelChipState extends State<_ModelChip> {
  final GlobalKey _chipKey = GlobalKey();
  bool _isHovered = false;

  void _showModelMenu(BuildContext context, AppThemeExtension appColors) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renderBox = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final targetOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissModelMenu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        return Stack(
          children: [
            Positioned(
              left: targetOffset.dx,
              bottom: overlay.size.height - targetOffset.dy + 8.0,
              child: Material(
                color: Colors.transparent,
                child: FrostedGlass(
                  width: 230.0,
                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                  borderRadius: BorderRadius.circular(16.0),
                  borderColor: appColors.borderSubtle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                      blurRadius: 18.0,
                      offset: const Offset(0, -6),
                    ),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.models.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            I18n.noModels,
                            style: AppTypography.uiControl.copyWith(
                              color: appColors.textSecondary,
                              fontSize: 12.0,
                            ),
                          ),
                        )
                      else
                        ...widget.models.map((m) {
                          final isCurrent = m.name == widget.selectedModel;
                          return InkWell(
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              widget.onModelChanged?.call(m.name);
                            },
                            borderRadius: BorderRadius.circular(10.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                              decoration: BoxDecoration(
                                color: isCurrent ? appColors.accentSubtle : Colors.transparent,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Row(
                                children: [
                                  if (isCurrent)
                                    Icon(Icons.check, size: 14.0, color: appColors.accent)
                                  else
                                    const SizedBox(width: 14.0),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Text(
                                      m.name,
                                      style: AppTypography.code.copyWith(
                                        color: isCurrent ? appColors.accent : appColors.textPrimary,
                                        fontSize: 12.0,
                                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      if (widget.onManageModels != null) ...[
                        const SizedBox(height: 4.0),
                        Divider(height: 1.0, color: appColors.borderSubtle),
                        const SizedBox(height: 4.0),
                        InkWell(
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            widget.onManageModels?.call();
                          },
                          borderRadius: BorderRadius.circular(10.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                            child: Row(
                              children: [
                                Icon(Icons.settings_outlined, size: 14.0, color: appColors.textSecondary),
                                const SizedBox(width: 8.0),
                                Text(
                                  I18n.manageModels,
                                  style: AppTypography.uiControl.copyWith(
                                    color: appColors.textSecondary,
                                    fontSize: 12.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: _chipKey,
        onTap: () => _showModelMenu(context, appColors),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
          decoration: BoxDecoration(
            color: appColors.background,
            border: Border.all(
              color: _isHovered ? appColors.accent : appColors.borderSubtle,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.selectedModel ?? I18n.selectModel,
                style: AppTypography.code.copyWith(
                  color: _isHovered ? appColors.accent : appColors.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4.0),
              Icon(
                Icons.keyboard_arrow_up,
                size: 13.0,
                color: _isHovered ? appColors.accent : appColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatefulWidget {
  final ChatExecutionMode mode;
  final ValueChanged<ChatExecutionMode>? onModeChanged;

  const _ModeChip({
    required this.mode,
    this.onModeChanged,
  });

  @override
  State<_ModeChip> createState() => _ModeChipState();
}

class _ModeChipState extends State<_ModeChip> {
  final GlobalKey _chipKey = GlobalKey();
  bool _isHovered = false;

  void _showModeMenu(BuildContext context, AppThemeExtension appColors) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renderBox = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final targetOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);

    final modes = [
      (
        mode: ChatExecutionMode.schnell,
        title: I18n.modeFast,
        desc: I18n.modeFastDesc,
        icon: Icons.bolt_rounded,
        iconColor: Colors.amber.shade600,
      ),
      (
        mode: ChatExecutionMode.optimal,
        title: I18n.modeOptimal,
        desc: I18n.modeOptimalDesc,
        icon: Icons.auto_awesome_rounded,
        iconColor: appColors.accent,
      ),
      (
        mode: ChatExecutionMode.thinking,
        title: I18n.modeThinking,
        desc: I18n.modeThinkingDesc,
        icon: Icons.psychology_rounded,
        iconColor: const Color(0xFF9C27B0),
      ),
    ];

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissModeMenu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        return Stack(
          children: [
            Positioned(
              left: targetOffset.dx,
              bottom: overlay.size.height - targetOffset.dy + 8.0,
              child: Material(
                color: Colors.transparent,
                child: FrostedGlass(
                  width: 250.0,
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                  borderRadius: BorderRadius.circular(16.0),
                  borderColor: appColors.borderSubtle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      blurRadius: 18.0,
                      offset: const Offset(0, -6),
                    ),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 6.0),
                        child: Text(
                          I18n.modeTitle,
                          style: AppTypography.uiControl.copyWith(
                            color: appColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      ...modes.map((item) {
                        final isCurrent = item.mode == widget.mode;
                        return InkWell(
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            widget.onModeChanged?.call(item.mode);
                          },
                          borderRadius: BorderRadius.circular(10.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 7.0),
                            decoration: BoxDecoration(
                              color: isCurrent ? appColors.accentSubtle : Colors.transparent,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Row(
                              children: [
                                Icon(item.icon, size: 16.0, color: item.iconColor),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.title,
                                        style: AppTypography.uiControl.copyWith(
                                          color: isCurrent ? appColors.accent : appColors.textPrimary,
                                          fontSize: 12.0,
                                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 1.0),
                                      Text(
                                        item.desc,
                                        style: AppTypography.uiControl.copyWith(
                                          color: appColors.textSecondary,
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCurrent)
                                  Icon(Icons.check_rounded, size: 14.0, color: appColors.accent),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    final IconData icon;
    final String label;
    final Color? iconColor;

    switch (widget.mode) {
      case ChatExecutionMode.schnell:
        icon = Icons.bolt_rounded;
        label = I18n.modeFast;
        iconColor = Colors.amber.shade600;
        break;
      case ChatExecutionMode.optimal:
        icon = Icons.auto_awesome_rounded;
        label = I18n.modeOptimal;
        iconColor = appColors.accent;
        break;
      case ChatExecutionMode.thinking:
        icon = Icons.psychology_rounded;
        label = I18n.modeThinking;
        iconColor = const Color(0xFF9C27B0);
        break;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: _chipKey,
        onTap: () => _showModeMenu(context, appColors),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.5),
          decoration: BoxDecoration(
            color: appColors.background,
            border: Border.all(
              color: _isHovered ? appColors.accent : appColors.borderSubtle,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13.0,
                color: _isHovered ? appColors.accent : iconColor,
              ),
              const SizedBox(width: 4.5),
              Text(
                label,
                style: AppTypography.uiControl.copyWith(
                  color: _isHovered ? appColors.accent : appColors.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 3.5),
              Icon(
                Icons.keyboard_arrow_up,
                size: 13.0,
                color: _isHovered ? appColors.accent : appColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

