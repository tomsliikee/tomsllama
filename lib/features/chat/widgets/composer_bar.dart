import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/persona.dart';
import '../../../core/models/ollama_model.dart';
import '../../../core/models/workspace_info.dart';
import '../../../core/models/attached_file.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';
import '../controllers/workspace_controller.dart';

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
  final double temperature;
  final ValueChanged<double>? onTemperatureChanged;

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
    this.temperature = 0.7,
    this.onTemperatureChanged,
  });

  @override
  ConsumerState<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends ConsumerState<ComposerBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<_SendButtonState> _sendButtonKey = GlobalKey<_SendButtonState>();
  bool _isDragging = false;
  bool _hasText = false;
  bool _isFocused = false;

  // Autocomplete '@' mention state
  bool _showAtPopup = false;
  int _atStartIndex = -1;
  List<String> _atMatches = [];
  int _atSelectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _focusNode.onKeyEvent = (node, event) => _onKeyEvent(event);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (_hasText != hasText && mounted) {
      setState(() => _hasText = hasText);
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
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                               HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
        if (!isShiftPressed) {
          _handleSend();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    final dirPaths = <String>[];
    final filePaths = <String>[];

    for (final file in details.files) {
      final path = file.path;
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        dirPaths.add(path);
      } else if (type == FileSystemEntityType.file) {
        filePaths.add(path);
      }
    }

    if (dirPaths.isNotEmpty) {
      for (final dirPath in dirPaths) {
        await ref.read(workspaceProvider.notifier).setWorkspace(dirPath);
      }
    }
    if (filePaths.isNotEmpty) {
      await ref.read(workspaceProvider.notifier).attachFiles(filePaths);
    }
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
          child: DropTarget(
            onDragEntered: (_) => setState(() => _isDragging = true),
            onDragExited: (_) => setState(() => _isDragging = false),
            onDragDone: (details) {
              setState(() => _isDragging = false);
              _handleDrop(details);
            },
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: appColors.surface, // #FFFFFF in Claude and Pond
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: (_isFocused || _isDragging) ? appColors.accent : appColors.borderSubtle,
                  width: 1.0,
                ),
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
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Active Workspace & Attached File Pills
                  if (workspaceState.workspace != null || workspaceState.attachedFiles.isNotEmpty) ...[
                    Padding(
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
                              onRemove: () => ref.read(workspaceProvider.notifier).removeAttachedFile(file.path),
                            ),
                          if (workspaceState.attachedFiles.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 2.0),
                              child: Text(
                                '~${(workspaceState.totalAttachedTokens / 1000).toStringAsFixed(1)}k tok',
                                style: AppTypography.code.copyWith(
                                  fontSize: 10.0,
                                  color: appColors.textSecondary.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Autocomplete popup for '@' mention
                  if (_showAtPopup && _atMatches.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      decoration: BoxDecoration(
                        color: appColors.surface,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: appColors.borderSubtle, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
                            blurRadius: 10.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
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
                                  'Workspace: ${workspaceState.workspace?.name ?? "Files"}',
                                  style: AppTypography.uiControl.copyWith(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w600,
                                    color: appColors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '↑↓ to navigate • Enter/Tab to select',
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

                  // Text Input
                  TextField(
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
                      hintText: _isDragging
                          ? (I18n.isGerman ? 'Datei oder Ordner hier ablegen...' : 'Drop file or folder here...')
                          : I18n.composerPlaceholder(widget.modelName ?? "qwen2.5:3b"),
                      hintStyle: AppTypography.uiControl.copyWith(
                        color: appColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: 14.0,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  
                  const SizedBox(height: 10.0),

                  // Bottom Bar: Chips with Wrap and Send Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Chips wrapped to prevent pixel overflow on resize or canvas split
                      Expanded(
                        child: Wrap(
                          spacing: 6.0,
                          runSpacing: 6.0,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _PersonaChip(
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
                            if (widget.onTemperatureChanged != null)
                              _TemperatureChip(
                                temperature: widget.temperature,
                                onTemperatureChanged: widget.onTemperatureChanged,
                              ),
                            _AttachChip(
                              onPickWorkspace: _pickWorkspace,
                              onAttachFolder: _pickFolderFiles,
                              onPickFiles: _pickFiles,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      // Send Button with Cute Llama Animation
                      _SendButton(
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
  final VoidCallback onRemove;

  const _AttachedFilePill({
    required this.file,
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
          Icon(Icons.description_outlined, size: 13.0, color: appColors.accent),
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
            '${file.estimatedTokens} tok',
            style: AppTypography.code.copyWith(
              fontSize: 10.0,
              color: appColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
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
                child: Container(
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(color: appColors.borderSubtle, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 12.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
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
                                'Open Project Workspace...',
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
                                'Attach Folder Files...',
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
                                'Attach Files...',
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
                  'Attach',
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

class _PersonaChip extends StatefulWidget {
  final String personaName;
  final VoidCallback onTap;
  final ValueChanged<String>? onSelectPersona;

  const _PersonaChip({
    required this.personaName,
    required this.onTap,
    this.onSelectPersona,
  });

  @override
  State<_PersonaChip> createState() => _PersonaChipState();
}

class _PersonaChipState extends State<_PersonaChip> {
  final GlobalKey _chipKey = GlobalKey();
  bool _isHovered = false;

  void _showPersonaMenu(BuildContext context, AppThemeExtension appColors) async {
    final renderBox = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      widget.onTap();
      return;
    }
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      widget.onTap();
      return;
    }

    final targetOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final ScrollController scrollController = ScrollController();

    // Primary roles (Standard, Senior Coder, Security Guard, Project Planner, Marketing Expert)
    const primaryOrder = ['standard', 'coder', 'security', 'planner', 'marketing'];
    final primaryPersonas = <Persona>[];
    for (final id in primaryOrder) {
      final match = Persona.defaultPersonas.where((p) => p.id == id);
      if (match.isNotEmpty) primaryPersonas.add(match.first);
    }

    // Additional roles (Deep Analyst, Tech Writer, Architect, Social Media Expert, Creative Writer)
    const additionalOrder = ['analyst', 'writer', 'architect', 'social_media', 'creative_writer'];
    final additionalPersonas = <Persona>[];
    for (final id in additionalOrder) {
      final match = Persona.defaultPersonas.where((p) => p.id == id);
      if (match.isNotEmpty) additionalPersonas.add(match.first);
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    // Dynamic height bounded between 165.0 and 225.0 depending on window height
    final double listHeight = (screenHeight * 0.30).clamp(165.0, 225.0);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissPersonaDialog',
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
                child: Container(
                  width: 295.0,
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: appColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 18.0,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        child: Text(
                          I18n.roleAndPrompt,
                          style: AppTypography.uiControl.copyWith(
                            color: appColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      SizedBox(
                        height: listHeight,
                        child: Scrollbar(
                          controller: scrollController,
                          thumbVisibility: true,
                          thickness: 3.5,
                          radius: const Radius.circular(4.0),
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.only(right: 6.0),
                            children: [
                              ...primaryPersonas.map((p) => _buildPersonaItem(p, dialogContext, appColors)),
                              Padding(
                                padding: const EdgeInsets.only(left: 10.0, top: 8.0, bottom: 4.0, right: 6.0),
                                child: Row(
                                  children: [
                                    Text(
                                      I18n.additionalRoles,
                                      style: AppTypography.uiControl.copyWith(
                                        color: appColors.textSecondary.withValues(alpha: 0.65),
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    Expanded(
                                      child: Container(
                                        height: 1.0,
                                        color: appColors.borderSubtle.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...additionalPersonas.map((p) => _buildPersonaItem(p, dialogContext, appColors)),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildPersonaItem(Persona p, BuildContext dialogContext, AppThemeExtension appColors) {
    final isCurrent = p.name.toLowerCase() == widget.personaName.toLowerCase();
    return InkWell(
      onTap: () {
        Navigator.of(dialogContext).pop();
        widget.onSelectPersona?.call(p.name);
        widget.onTap();
      },
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.5),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: AppTypography.uiControl.copyWith(
                      color: isCurrent ? appColors.accent : appColors.textPrimary,
                      fontSize: 12.0,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (p.description.isNotEmpty)
                    Text(
                      p.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.uiControl.copyWith(
                        color: appColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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
        onTap: () {
          if (widget.onSelectPersona != null) {
            _showPersonaMenu(context, appColors);
          } else {
            widget.onTap();
          }
        },
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
                I18n.roleLabel,
                style: AppTypography.uiControl.copyWith(
                  color: _isHovered ? appColors.accent : appColors.textSecondary,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                widget.personaName,
                style: AppTypography.uiControl.copyWith(
                  color: _isHovered ? appColors.accent : appColors.textSecondary,
                  fontSize: 11.0,
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
                child: Container(
                  width: 230.0,
                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: appColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 18.0,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
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

class _TemperatureChip extends StatefulWidget {
  final double temperature;
  final ValueChanged<double>? onTemperatureChanged;

  const _TemperatureChip({
    required this.temperature,
    this.onTemperatureChanged,
  });

  @override
  State<_TemperatureChip> createState() => _TemperatureChipState();
}

class _TemperatureChipState extends State<_TemperatureChip> {
  final GlobalKey _chipKey = GlobalKey();
  bool _isHovered = false;

  void _showTemperaturePopover(BuildContext context, AppThemeExtension appColors) async {
    final renderBox = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final targetOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    double currentTemp = widget.temperature;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissTempPopover',
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
        return StatefulBuilder(
          builder: (context, setPopoverState) {
            return Stack(
              children: [
                Positioned(
                  left: targetOffset.dx,
                  bottom: overlay.size.height - targetOffset.dy + 8.0,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 275.0,
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: appColors.surface,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: appColors.borderSubtle),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 18.0,
                            offset: const Offset(0, -6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                I18n.temperature,
                                style: AppTypography.uiControl.copyWith(
                                  color: appColors.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: appColors.accentSubtle,
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Text(
                                  currentTemp.toStringAsFixed(2),
                                  style: AppTypography.code.copyWith(
                                    color: appColors.accent,
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10.0),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: appColors.accent,
                              inactiveTrackColor: appColors.borderSubtle,
                              thumbColor: appColors.accent,
                              overlayColor: appColors.accent.withValues(alpha: 0.15),
                              trackHeight: 3.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                            ),
                            child: Slider(
                              value: currentTemp,
                              min: 0.0,
                              max: 1.0,
                              divisions: 20,
                              onChanged: (val) {
                                setPopoverState(() => currentTemp = val);
                                widget.onTemperatureChanged?.call(val);
                              },
                            ),
                          ),
                          const SizedBox(height: 6.0),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTempPreset(
                                  label: I18n.tempCode,
                                  isSelected: (currentTemp - 0.2).abs() < 0.01,
                                  onTap: () {
                                    setPopoverState(() => currentTemp = 0.2);
                                    widget.onTemperatureChanged?.call(0.2);
                                  },
                                  appColors: appColors,
                                ),
                              ),
                              const SizedBox(width: 5.0),
                              Expanded(
                                child: _buildTempPreset(
                                  label: I18n.tempNormal,
                                  isSelected: (currentTemp - 0.7).abs() < 0.01,
                                  onTap: () {
                                    setPopoverState(() => currentTemp = 0.7);
                                    widget.onTemperatureChanged?.call(0.7);
                                  },
                                  appColors: appColors,
                                ),
                              ),
                              const SizedBox(width: 5.0),
                              Expanded(
                                child: _buildTempPreset(
                                  label: I18n.tempCreative,
                                  isSelected: (currentTemp - 1.0).abs() < 0.01,
                                  onTap: () {
                                    setPopoverState(() => currentTemp = 1.0);
                                    widget.onTemperatureChanged?.call(1.0);
                                  },
                                  appColors: appColors,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTempPreset({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppThemeExtension appColors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? appColors.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isSelected ? appColors.accent.withValues(alpha: 0.3) : appColors.borderSubtle,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.uiControl.copyWith(
              color: isSelected ? appColors.accent : appColors.textSecondary,
              fontSize: 10.0,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
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
        onTap: () => _showTemperaturePopover(context, appColors),
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
                Icons.tune,
                size: 12.5,
                color: _isHovered ? appColors.accent : appColors.textSecondary,
              ),
              const SizedBox(width: 4.5),
              Text(
                widget.temperature.toStringAsFixed(1),
                style: AppTypography.code.copyWith(
                  color: _isHovered ? appColors.accent : appColors.textSecondary,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 3.0),
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

class _SendButton extends StatefulWidget {
  final bool isGenerating;
  final bool hasText;
  final VoidCallback? onTap;

  const _SendButton({
    super.key,
    required this.isGenerating,
    required this.hasText,
    required this.onTap,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  int _animIndex = 0;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    // 15% longer animation duration (1500ms -> 1725ms)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1725),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void triggerCuteAnimation() {
    if (!mounted) return;
    setState(() {
      _animIndex = (_animIndex + 1) % 3;
    });
    _animController.forward(from: 0.0);
  }

  double _calculateHeightFactor(double t) {
    if (t < 0.16) {
      final subT = (t / 0.16).clamp(0.0, 1.0);
      return Curves.easeOutBack.transform(subT).clamp(0.0, 1.08);
    } else if (t < 0.82) {
      return 1.0;
    } else {
      final subT = ((t - 0.82) / 0.18).clamp(0.0, 1.0);
      return (1.0 - Curves.easeInOutCubic.transform(subT)).clamp(0.0, 1.0);
    }
  }

  double _calculateCuteProgress(double t) {
    if (t < 0.16) return 0.0;
    if (t > 0.82) return 1.0;
    return ((t - 0.16) / 0.66).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = widget.isGenerating
        ? appColors.surface
        : (widget.hasText
            ? appColors.accent
            : (_isHovered ? appColors.surface : appColors.background));

    final textColor = widget.isGenerating
        ? appColors.textPrimary
        : (widget.hasText ? Colors.white : appColors.textSecondary.withValues(alpha: 0.7));

    final borderColor = widget.isGenerating
        ? appColors.borderSubtle
        : (widget.hasText
            ? appColors.accent
            : (_isHovered ? appColors.border : appColors.borderSubtle));

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final double animValue = _animController.value;
        final double heightFactor = animValue > 0.0 ? _calculateHeightFactor(animValue) : 0.0;
        final double cuteProgress = animValue > 0.0 ? _calculateCuteProgress(animValue) : 0.0;
        final double extensionHeight = heightFactor * 44.0;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: () {
              if (widget.onTap != null) {
                if (!widget.isGenerating && widget.hasText) {
                  triggerCuteAnimation();
                }
                widget.onTap!();
              }
            },
            child: AnimatedScale(
              scale: _isPressed ? 0.94 : (_isHovered && (widget.hasText || widget.isGenerating) ? 1.02 : 1.0),
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutBack,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: extensionHeight > 1.0
                      ? [
                          BoxShadow(
                            color: appColors.accent.withValues(alpha: 0.32),
                            blurRadius: 14.0,
                            offset: const Offset(0, -4),
                          ),
                        ]
                      : (widget.hasText
                          ? [
                              BoxShadow(
                                color: appColors.accent.withValues(alpha: isDark ? 0.32 : 0.22),
                                blurRadius: 8.0,
                                offset: const Offset(0, 2),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                                blurRadius: 3.0,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cute upward animated Llama extension
                    if (extensionHeight > 0.5)
                      SizedBox(
                        height: extensionHeight,
                        width: 82.0,
                        child: ClipRect(
                          child: CustomPaint(
                            painter: _CuteLlamaPainter(
                              cuteProgress: cuteProgress,
                              animType: _animIndex,
                              llamaColor: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // Base Send Button Content with refined icon & label
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isGenerating
                                ? Icons.stop_rounded
                                : Icons.arrow_upward_rounded,
                            size: 13.5,
                            color: textColor,
                          ),
                          const SizedBox(width: 4.5),
                          Text(
                            widget.isGenerating ? I18n.stop : I18n.send,
                            style: AppTypography.uiControl.copyWith(
                              color: textColor,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Painter for the cute Llama animation with 3 joyful variations:
/// 0: Ear Wiggle & Sparkles
/// 1: Bouncy Hop & Floating Heart
/// 2: Eager Nod & Wink
class _CuteLlamaPainter extends CustomPainter {
  final double cuteProgress; // 0.0 to 1.0
  final int animType;        // 0, 1, 2
  final Color llamaColor;

  _CuteLlamaPainter({
    required this.cuteProgress,
    required this.animType,
    required this.llamaColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 1.0);

    double yOffset = 0.0;
    double rotation = 0.0;
    bool isWinking = false;
    double earWiggle = 0.0;

    if (animType == 0) {
      // 0: Ear Wiggle & Sparkles
      rotation = math.sin(cuteProgress * math.pi * 4) * 0.08;
      earWiggle = math.sin(cuteProgress * math.pi * 8) * 0.25;
    } else if (animType == 1) {
      // 1: Bouncy Hop & Floating Heart
      yOffset = -((math.sin(cuteProgress * math.pi * 4)).abs()) * 4.0;
      rotation = math.sin(cuteProgress * math.pi * 2) * 0.04;
    } else {
      // 2: Eager Nod & Wink
      yOffset = math.sin(cuteProgress * math.pi * 6) * 2.2;
      isWinking = cuteProgress >= 0.25 && cuteProgress <= 0.70;
    }

    canvas.save();
    canvas.translate(center.dx, center.dy + yOffset);
    canvas.rotate(rotation);

    // Draw cute Llama head, neck, and ears
    _drawLlama(canvas, earWiggle, isWinking);

    canvas.restore();

    // Draw floating cute effects in canvas coordinate space
    if (animType == 0) {
      _drawSparkles(canvas, center);
    } else if (animType == 1) {
      _drawHeart(canvas, center);
    } else {
      _drawNodStars(canvas, center);
    }
  }

  void _drawLlama(Canvas canvas, double earWiggle, bool isWinking) {
    const double scale = 0.82;

    final Path bodyPath = Path()
      ..moveTo(-5.0 * scale, 10.0 * scale)
      ..lineTo(-4.5 * scale, 0.0 * scale)
      // Left ear (with gentle wiggle)
      ..lineTo((-5.5 + earWiggle * 2.2) * scale, -9.5 * scale)
      ..lineTo(-2.0 * scale, -4.5 * scale)
      // Right ear (with opposite gentle wiggle)
      ..lineTo((0.5 - earWiggle * 2.2) * scale, -8.5 * scale)
      ..lineTo(2.0 * scale, -3.0 * scale)
      // Snout
      ..lineTo(8.5 * scale, -1.0 * scale)
      ..lineTo(9.0 * scale, 2.0 * scale)
      ..lineTo(7.0 * scale, 3.5 * scale)
      ..lineTo(3.5 * scale, 3.5 * scale)
      ..lineTo(4.0 * scale, 10.0 * scale)
      ..close();

    // Body fill
    final fillPaint = Paint()
      ..color = llamaColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, fillPaint);

    // Body outline
    final outlinePaint = Paint()
      ..color = llamaColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(bodyPath, outlinePaint);

    // Cute blush cheek
    final blushPaint = Paint()
      ..color = Colors.pinkAccent.shade100.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(3.69, 1.64), 1.31, blushPaint);

    // Eye: round dot or cute wink arc
    if (isWinking) {
      final winkPaint = Paint()
        ..color = llamaColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        const Offset(0.41, -0.41),
        const Offset(2.46, 0.41),
        winkPaint,
      );
    } else {
      final eyePaint = Paint()
        ..color = llamaColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(1.64, -0.41), 0.82, eyePaint);
    }
  }

  void _drawSparkles(Canvas canvas, Offset center) {
    final double sparkleScale = (math.sin(cuteProgress * math.pi)).clamp(0.0, 1.0);
    if (sparkleScale <= 0.05) return;

    // Sparkle 1: Top-left gold star
    final Offset s1 = Offset(center.dx - 18.0, center.dy - 8.0);
    _draw4PointStar(canvas, s1, 3.8 * sparkleScale, Colors.amberAccent);

    // Sparkle 2: Top-right bright star
    final Offset s2 = Offset(center.dx + 16.0, center.dy - 10.0);
    _draw4PointStar(canvas, s2, 3.2 * sparkleScale, Colors.white);
  }

  void _drawHeart(Canvas canvas, Offset center) {
    final double heartProgress = (cuteProgress * 1.3).clamp(0.0, 1.0);
    if (heartProgress <= 0.05 || heartProgress >= 0.95) return;

    final double hx = center.dx + 14.0;
    final double hy = center.dy - 4.0 - heartProgress * 15.0;
    final double hs = (math.sin(heartProgress * math.pi)).clamp(0.0, 1.0) * 2.2;

    final Path heartPath = Path()
      ..moveTo(hx, hy + hs * 0.8)
      ..cubicTo(hx - hs * 1.8, hy - hs * 1.5, hx - hs * 2.5, hy + hs * 0.8, hx, hy + hs * 2.5)
      ..cubicTo(hx + hs * 2.5, hy + hs * 0.8, hx + hs * 1.8, hy - hs * 1.5, hx, hy + hs * 0.8)
      ..close();

    final Paint heartPaint = Paint()
      ..color = Colors.pinkAccent.shade100.withValues(alpha: (1.0 - heartProgress * 0.7))
      ..style = PaintingStyle.fill;
    canvas.drawPath(heartPath, heartPaint);
  }

  void _drawNodStars(Canvas canvas, Offset center) {
    final double starScale = (math.sin(cuteProgress * math.pi)).clamp(0.0, 1.0);
    if (starScale <= 0.05) return;

    // A tiny star floating from the snout
    final Offset p1 = Offset(center.dx + 17.0, center.dy - 6.0);
    _draw4PointStar(canvas, p1, 3.0 * starScale, Colors.amberAccent);

    final Offset p2 = Offset(center.dx - 16.0, center.dy - 5.0);
    _draw4PointStar(canvas, p2, 2.4 * starScale, Colors.white);
  }

  void _draw4PointStar(Canvas canvas, Offset pos, double size, Color color) {
    final Path path = Path()
      ..moveTo(pos.dx, pos.dy - size)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx + size, pos.dy)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + size)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx - size, pos.dy)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - size)
      ..close();

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CuteLlamaPainter oldDelegate) {
    return oldDelegate.cuteProgress != cuteProgress ||
        oldDelegate.animType != animType ||
        oldDelegate.llamaColor != llamaColor;
  }
}
