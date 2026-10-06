import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tray_manager/tray_manager.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/export_service.dart';
import '../../settings/controllers/settings_controller.dart';
import '../../sidebar/controllers/sidebar_controller.dart';
import '../../models/controllers/model_controller.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../chat/controllers/workspace_controller.dart';
import '../../sidebar/widgets/sidebar_view.dart';
import '../../chat/widgets/chat_viewport.dart';
import '../../chat/widgets/composer_bar.dart';
import '../../chat/widgets/file_drop_overlay.dart';
import '../../chat/widgets/artifact_canvas_view.dart';
import 'csd_header_bar.dart';
import '../../models/widgets/quick_switcher_modal.dart';
import '../../models/widgets/model_manager_dialog.dart';
import '../../settings/widgets/settings_dialog.dart';
import '../../../core/models/workspace.dart';
import '../../../core/services/localization_service.dart';
import '../../workspace/controllers/workspace_hub_controller.dart';
import '../../workspace/widgets/workspace_hub_view.dart';
import '../../workspace/widgets/new_workspace_dialog.dart';

class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> with WindowListener, TrayListener {
  bool _isSidebarOpen = true;
  bool _isZenMode = false;
  bool _isDraggingOverChat = false;
  bool _isViewingWorkspaceHub = false;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _applyCloseBehavior(ref.read(appSettingsProvider).closeToTray);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sidebarNotifier = ref.read(sidebarProvider.notifier);
      await sidebarNotifier.loadConversations();
      await ref.read(workspaceListProvider.notifier).loadWorkspaces();
      final conversations = ref.read(sidebarProvider).conversations;
      
      // If there are existing conversations, check if the newest one is already empty
      if (conversations.isNotEmpty) {
        final newest = conversations.first;
        final msgs = await DatabaseService().getMessagesForConversation(newest.id);
        if (msgs.isEmpty) {
          sidebarNotifier.setActiveConversation(newest.id);
          await ref.read(chatProvider.notifier).loadConversation(newest.id);
          return;
        }
      }

      // Otherwise automatically start a fresh new chat, preserving existing chats
      await ref.read(chatProvider.notifier).startNewChat();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  // With close-to-tray on, the close button is intercepted and hides the window;
  // "Exit" in the tray menu is then the way out.
  Future<void> _applyCloseBehavior(bool closeToTray) async {
    try {
      await windowManager.setPreventClose(closeToTray);
    } catch (_) {
      // No native window (tests).
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      _showWindow();
    } else if (menuItem.key == 'exit_app') {
      windowManager.destroy();
    }
  }

  Future<void> _exportChat(String conversationId) async {
    final conv = ref.read(sidebarProvider).conversations.where((c) => c.id == conversationId).firstOrNull;
    if (conv == null) return;

    final safeTitle = conv.title.replaceAll(RegExp(r'[^\w\s.-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
    final path = await FilePicker.platform.saveFile(
      dialogTitle: I18n.exportDialogTitle,
      fileName: '${safeTitle.isEmpty ? 'chat' : safeTitle}.md',
      type: FileType.custom,
      allowedExtensions: const ['md', 'json', 'html'],
    );
    if (path == null) return;

    // The extension the user typed picks the format; anything else is Markdown.
    final messages = await DatabaseService().getMessagesForConversation(conversationId);
    final lower = path.toLowerCase();
    if (lower.endsWith('.json')) {
      await ExportService.exportToJson(conv, messages, path);
    } else if (lower.endsWith('.html')) {
      await ExportService.exportToHtml(conv, messages, path);
    } else {
      await ExportService.exportToMarkdown(conv, messages, lower.endsWith('.md') ? path : '$path.md');
    }
  }

  void _toggleSidebar() => setState(() => _isSidebarOpen = !_isSidebarOpen);
  
  void _toggleZenMode() => setState(() {
    _isZenMode = !_isZenMode;
    windowManager.setFullScreen(_isZenMode);
  });

  void _openQuickSwitcher() {
    final conversations = ref.read(sidebarProvider).conversations;
    showDialog(
      context: context,
      builder: (_) => QuickSwitcherModal(
        conversations: conversations,
        onSelect: (id) {
          setState(() => _isViewingWorkspaceHub = false);
          ref.read(sidebarProvider.notifier).setActiveConversation(id);
          ref.read(chatProvider.notifier).loadConversation(id);
        },
      ),
    );
  }

  void _openSettings() {
    showDialog(context: context, builder: (_) => const SettingsDialog());
  }

  void _openModelManager() {
    showDialog(context: context, builder: (_) => const ModelManagerDialog());
  }

  void _newChat() async {
    setState(() => _isViewingWorkspaceHub = false);
    await ref.read(chatProvider.notifier).startNewChat();
  }

  Future<void> _openNewWorkspaceDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const NewWorkspaceDialog(),
    );
    if (result != null && result['name'] != null && result['name']!.isNotEmpty) {
      final ws = await ref.read(workspaceListProvider.notifier).createNewWorkspace(
        name: result['name']!,
        prompt: result['prompt'] ?? '',
      );
      await ref.read(activeWorkspaceProvider.notifier).loadWorkspace(ws.id);
      setState(() => _isViewingWorkspaceHub = true);
    }
  }

  Future<void> _handleChatDrop(DropDoneDetails details) async {
    final activeConvId = ref.read(chatProvider).conversationId;
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

    final wsNotifier = ref.read(workspaceProvider.notifier);
    if (dirPaths.isNotEmpty) {
      for (final dirPath in dirPaths) {
        await wsNotifier.setWorkspace(dirPath, conversationId: activeConvId);
      }
    }
    if (filePaths.isNotEmpty) {
      await wsNotifier.attachFiles(filePaths, conversationId: activeConvId);
    }
  }

  Widget _buildWorkspaceHeaderBar({
    required BuildContext context,
    required AppThemeExtension appColors,
    required Workspace workspace,
    required bool isContextEnabled,
    required VoidCallback onToggleContext,
    required VoidCallback onBackToHub,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 0.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
      decoration: BoxDecoration(
        color: appColors.sidebar,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: appColors.borderSubtle, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(Icons.workspaces_outlined, size: 16.0, color: appColors.textSecondary),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              workspace.name,
              style: AppTypography.headline.copyWith(
                fontFamily: AppTypography.serifFamily,
                fontStyle: FontStyle.italic,
                color: appColors.textPrimary,
                fontWeight: FontWeight.w400,
                fontSize: 15.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10.0),
          // Toggle Button Pill
          InkWell(
            onTap: onToggleContext,
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
              decoration: BoxDecoration(
                color: appColors.background,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: appColors.borderSubtle, width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7.0,
                    height: 7.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isContextEnabled ? appColors.accent : appColors.textSecondary.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    isContextEnabled ? I18n.contextActive : I18n.contextPaused,
                    style: AppTypography.uiControl.copyWith(
                      color: isContextEnabled ? appColors.textPrimary : appColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          // Back to Hub Button Pill
          InkWell(
            onTap: onBackToHub,
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
              decoration: BoxDecoration(
                color: appColors.background,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: appColors.borderSubtle, width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 13.0, color: appColors.textSecondary),
                  const SizedBox(width: 4.0),
                  Text(
                    I18n.backToHub,
                    style: AppTypography.uiControl.copyWith(
                      color: appColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
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

    ref.listen(appSettingsProvider.select((s) => s.closeToTray), (_, closeToTray) {
      _applyCloseBehavior(closeToTray);
    });

    final sidebarState = ref.watch(sidebarProvider);
    final modelState = ref.watch(modelProvider);
    // Watch only what the shell itself lays out. The streaming message list is
    // watched further down, so a new token does not rebuild header and sidebar.
    final conversationId = ref.watch(chatProvider.select((s) => s.conversationId));
    final isCanvasOpen = ref.watch(chatProvider.select((s) => s.isCanvasOpen));
    final canvasContent = ref.watch(chatProvider.select((s) => s.canvasContent));
    final canvasLanguage = ref.watch(chatProvider.select((s) => s.canvasLanguage));
    final generatingIds = ref.watch(chatProvider.select((s) => s.generatingConversationIds));
    final sidebarMode = ref.watch(sidebarModeProvider);
    final workspaceListState = ref.watch(workspaceListProvider);
    final activeWsState = ref.watch(activeWorkspaceProvider);

    final chatNotifier = ref.read(chatProvider.notifier);
    final sidebarNotifier = ref.read(sidebarProvider.notifier);
    final modelNotifier = ref.read(modelProvider.notifier);

    final selectedModel = modelState.selectedModel ??
        (modelState.models.isNotEmpty ? modelState.models.first.name : 'qwen2.5:3b');

    final currentConv = sidebarState.conversations
        .where((c) => c.id == (conversationId ?? sidebarState.activeConversationId))
        .firstOrNull;
    final isWorkspaceChat = currentConv?.workspaceId != null;
    final currentConvWs = isWorkspaceChat
        ? workspaceListState.workspaces.where((w) => w.id == currentConv!.workspaceId).firstOrNull
        : null;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyB, control: true): _SidebarIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, control: true): _SearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, control: true): _NewChatIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _StopIntent(),
        SingleActivator(LogicalKeyboardKey.f11): _ZenModeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SidebarIntent: CallbackAction<_SidebarIntent>(onInvoke: (_) => _toggleSidebar()),
          _SearchIntent: CallbackAction<_SearchIntent>(onInvoke: (_) => _openQuickSwitcher()),
          _NewChatIntent: CallbackAction<_NewChatIntent>(onInvoke: (_) => _newChat()),
          _StopIntent: CallbackAction<_StopIntent>(onInvoke: (_) => chatNotifier.stopGeneration()),
          _ZenModeIntent: CallbackAction<_ZenModeIntent>(onInvoke: (_) => _toggleZenMode()),
        },
        child: FocusScope(
          autofocus: true,
          child: Scaffold(
            backgroundColor: appColors.background,
            body: Column(
              children: [
                CsdHeaderBar(
                  onToggleSidebar: _toggleSidebar,
                  onOpenSettings: _openSettings,
                  onOpenQuickSwitcher: _openQuickSwitcher,
                  isZenMode: _isZenMode,
                  isSidebarOpen: _isSidebarOpen,
                ),
                Expanded(
                  child: Row(
                    children: [
                      // Sidebar
                      if (_isSidebarOpen && !_isZenMode)
                        SidebarView(
                          conversations: sidebarState.filteredConversations,
                          activeConversationId: conversationId ?? sidebarState.activeConversationId,
                          generatingConversationIds: generatingIds,
                          searchController: _searchController,
                          onSearchChanged: (q) {
                            sidebarNotifier.setSearchQuery(q);
                            ref.read(workspaceListProvider.notifier).setSearchQuery(q);
                          },
                          onSearchClear: () {
                            _searchController.clear();
                            sidebarNotifier.setSearchQuery('');
                            ref.read(workspaceListProvider.notifier).setSearchQuery('');
                          },
                          onNewChat: _newChat,
                          onSelectChat: (id) {
                            setState(() => _isViewingWorkspaceHub = false);
                            sidebarNotifier.setActiveConversation(id);
                            chatNotifier.loadConversation(id);
                          },
                          onDeleteChat: (id) async {
                            chatNotifier.discardGeneration(id);
                            await sidebarNotifier.deleteConversation(id);
                            ref.read(workspaceProvider.notifier).removeConversation(id);
                            ref.read(activeWorkspaceProvider.notifier).refresh();
                            if (ref.read(chatProvider).conversationId == id) {
                              final remaining = ref.read(sidebarProvider).conversations;
                              if (remaining.isNotEmpty) {
                                sidebarNotifier.setActiveConversation(remaining.first.id);
                                chatNotifier.loadConversation(remaining.first.id);
                              } else {
                                await chatNotifier.startNewChat();
                              }
                            }
                          },
                          onTogglePinChat: (id) => sidebarNotifier.togglePin(id),
                          onReorder: (oldIndex, newIndex) =>
                              sidebarNotifier.reorderConversations(oldIndex, newIndex),
                          onExportChat: _exportChat,
                          // Claude Workspace Integration
                          mode: sidebarMode,
                          onModeChanged: (newMode) {
                            ref.read(sidebarModeProvider.notifier).state = newMode;
                            if (newMode == SidebarMode.workspaces) {
                              final activeWsId = ref.read(workspaceListProvider).activeWorkspaceId;
                              if (activeWsId != null) {
                                ref.read(activeWorkspaceProvider.notifier).loadWorkspace(activeWsId);
                                setState(() => _isViewingWorkspaceHub = true);
                              } else {
                                final allWs = ref.read(workspaceListProvider).workspaces;
                                if (allWs.isNotEmpty) {
                                  ref.read(workspaceListProvider.notifier).setActiveWorkspace(allWs.first.id);
                                  ref.read(activeWorkspaceProvider.notifier).loadWorkspace(allWs.first.id);
                                  setState(() => _isViewingWorkspaceHub = true);
                                }
                              }
                            } else {
                              setState(() => _isViewingWorkspaceHub = false);
                            }
                          },
                          workspaces: workspaceListState.filteredWorkspaces,
                          activeWorkspaceId: workspaceListState.activeWorkspaceId,
                          onSelectWorkspace: (id) async {
                            ref.read(workspaceListProvider.notifier).setActiveWorkspace(id);
                            await ref.read(activeWorkspaceProvider.notifier).loadWorkspace(id);
                            setState(() => _isViewingWorkspaceHub = true);
                          },
                          onNewWorkspace: _openNewWorkspaceDialog,
                          onDeleteWorkspace: (id) async {
                            await ref.read(workspaceListProvider.notifier).deleteWorkspace(id);
                            if (ref.read(activeWorkspaceProvider).workspace?.id == id) {
                              ref.read(activeWorkspaceProvider.notifier).clear();
                              setState(() => _isViewingWorkspaceHub = false);
                            }
                          },
                          onTogglePinWorkspace: (id) => ref.read(workspaceListProvider.notifier).togglePin(id),
                          onReorderWorkspaces: (oldIdx, newIdx) =>
                              ref.read(workspaceListProvider.notifier).reorderWorkspaces(oldIdx, newIdx),
                        ),
                      
                      // Main Chat & Split-View Canvas Area
                      Expanded(
                        child: ArtifactCanvasView(
                          isCanvasOpen: isCanvasOpen,
                          onCloseCanvas: () => chatNotifier.closeCanvas(),
                          language: canvasLanguage,
                          onCopy: () {
                            if (canvasContent != null) {
                              Clipboard.setData(ClipboardData(text: canvasContent));
                            }
                          },
                          canvasPanel: Container(
                            color: appColors.codeBackground,
                            padding: const EdgeInsets.all(16.0),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                canvasContent ?? '',
                                style: AppTypography.code.copyWith(
                                  color: appColors.textPrimary,
                                  fontSize: 13.0,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                          chatPanel: Padding(
                            padding: EdgeInsets.fromLTRB(4.0, 10.0, isCanvasOpen ? 5.0 : 10.0, 12.0),
                            child: _isViewingWorkspaceHub && activeWsState.workspace != null
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: appColors.surface,
                                      borderRadius: BorderRadius.circular(18.0),
                                      border: Border.all(
                                        color: appColors.borderSubtle,
                                        width: 1.0,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: WorkspaceHubView(
                                      workspace: activeWsState.workspace!,
                                      files: activeWsState.files,
                                      chats: activeWsState.chats,
                                      onStartChat: (prompt, model, persona) async {
                                        final ws = ref.read(activeWorkspaceProvider).workspace;
                                        if (ws == null) return;
                                        final title = prompt.length > 25 ? '${prompt.substring(0, 25)}...' : prompt;
                                        final newConv = await ref.read(sidebarProvider.notifier).createNewConversation(
                                          title: title,
                                          persona: persona,
                                          workspaceId: ws.id,
                                          isWorkspaceContextEnabled: true,
                                        );
                                        setState(() => _isViewingWorkspaceHub = false);
                                        sidebarNotifier.setActiveConversation(newConv.id);
                                        await ref.read(chatProvider.notifier).loadConversation(newConv.id);
                                        ref.read(chatProvider.notifier).setPersona(persona);
                                        if (model.isNotEmpty) {
                                          ref.read(modelProvider.notifier).selectModel(model);
                                        }
                                        ref.read(chatProvider.notifier).sendMessage(prompt, model.isNotEmpty ? model : selectedModel);
                                        ref.read(activeWorkspaceProvider.notifier).refresh();
                                      },
                                      onOpenChat: (convId) {
                                        setState(() => _isViewingWorkspaceHub = false);
                                        sidebarNotifier.setActiveConversation(convId);
                                        chatNotifier.loadConversation(convId);
                                      },
                                      onDeleteChat: (convId) async {
                                        chatNotifier.discardGeneration(convId);
                                        await sidebarNotifier.deleteConversation(convId);
                                        ref.read(activeWorkspaceProvider.notifier).refresh();
                                      },
                                    ),
                                  )
                                : DropTarget(
                                    onDragEntered: (_) => setState(() => _isDraggingOverChat = true),
                                    onDragExited: (_) => setState(() => _isDraggingOverChat = false),
                                    onDragDone: (details) {
                                      setState(() => _isDraggingOverChat = false);
                                      _handleChatDrop(details);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: appColors.surface,
                                        borderRadius: BorderRadius.circular(18.0),
                                        border: Border.all(
                                          color: _isDraggingOverChat ? appColors.accent : appColors.borderSubtle,
                                          width: 1.0,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        children: [
                                          Column(
                                            children: [
                                              // Workspace Context Pill Banner if this chat belongs to a workspace
                                              if (isWorkspaceChat && currentConvWs != null)
                                                _buildWorkspaceHeaderBar(
                                                  context: context,
                                                  appColors: appColors,
                                                  workspace: currentConvWs,
                                                  isContextEnabled: currentConv!.isWorkspaceContextEnabled,
                                                  onToggleContext: () {
                                                    sidebarNotifier.toggleWorkspaceContext(
                                                      currentConv.id,
                                                      !currentConv.isWorkspaceContextEnabled,
                                                    );
                                                  },
                                                  onBackToHub: () async {
                                                    ref.read(workspaceListProvider.notifier).setActiveWorkspace(currentConvWs.id);
                                                    await ref.read(activeWorkspaceProvider.notifier).loadWorkspace(currentConvWs.id);
                                                    setState(() => _isViewingWorkspaceHub = true);
                                                  },
                                                ),
                                              Expanded(
                                                child: AnimatedSwitcher(
                                                  duration: const Duration(milliseconds: 240),
                                                  switchInCurve: Curves.easeOutCubic,
                                                  switchOutCurve: Curves.easeInCubic,
                                                  transitionBuilder: (child, animation) {
                                                    return SlideTransition(
                                                      position: Tween<Offset>(
                                                        begin: const Offset(0.04, 0.0),
                                                        end: Offset.zero,
                                                      ).animate(animation),
                                                      child: FadeTransition(
                                                        opacity: animation,
                                                        child: child,
                                                      ),
                                                    );
                                                  },
                                                  child: KeyedSubtree(
                                                    key: ValueKey(conversationId ?? 'empty_chat'),
                                                    child: Consumer(
                                                      builder: (context, ref, _) {
                                                        final chatState = ref.watch(chatProvider);
                                                        return ChatViewport(
                                                          messages: chatState.messages,
                                                          isGenerating: chatState.isGenerating,
                                                          modelName: selectedModel,
                                                          statusMessage: chatState.statusMessage,
                                                          statusTokens: chatState.statusTokens,
                                                          onRegenerate: () => chatNotifier.regenerateLast(selectedModel),
                                                          // A failed model listing means the daemon is down; offer to look again.
                                                          errorMessage: chatState.errorMessage ?? modelState.errorMessage,
                                                          onRetry: chatState.errorMessage == null && modelState.errorMessage != null
                                                              ? () => modelNotifier.loadModels()
                                                              : null,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Consumer(
                                                builder: (context, ref, _) {
                                                  final (isGenerating, activePersonaName, mode) = ref.watch(
                                                    chatProvider.select((s) => (s.isGenerating, s.activePersonaName, s.mode)),
                                                  );
                                                  return ComposerBar(
                                                    isGenerating: isGenerating,
                                                    activePersonaName: activePersonaName,
                                                    modelName: selectedModel,
                                                    models: modelState.models,
                                                    selectedModel: selectedModel,
                                                    onModelChanged: (m) {
                                                      if (m != null) modelNotifier.selectModel(m);
                                                    },
                                                    onManageModels: _openModelManager,
                                                    mode: mode,
                                                    onModeChanged: (m) => chatNotifier.setMode(m),
                                                    onPersonaTap: () {},
                                                    onSelectPersona: (persona) => chatNotifier.setPersona(persona),
                                                    onSend: (text) => chatNotifier.sendMessage(text, selectedModel),
                                                    onStop: () => chatNotifier.stopGeneration(),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          if (_isDraggingOverChat)
                                            const Positioned.fill(
                                              child: IgnorePointer(
                                                child: FileDropOverlay(),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
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
  }
}

class _SidebarIntent extends Intent { const _SidebarIntent(); }
class _SearchIntent extends Intent { const _SearchIntent(); }
class _NewChatIntent extends Intent { const _NewChatIntent(); }
class _StopIntent extends Intent { const _StopIntent(); }
class _ZenModeIntent extends Intent { const _ZenModeIntent(); }
