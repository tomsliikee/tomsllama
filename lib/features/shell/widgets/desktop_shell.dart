import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/frosted_glass.dart';
import '../../../core/services/database_service.dart';
import '../../sidebar/controllers/sidebar_controller.dart';
import '../../models/controllers/model_controller.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../chat/controllers/workspace_controller.dart';
import '../../sidebar/widgets/sidebar_view.dart';
import '../../chat/widgets/chat_viewport.dart';
import '../../chat/widgets/composer_bar.dart';
import '../../chat/widgets/file_drop_overlay.dart';
import '../../chat/widgets/artifact_canvas_view.dart';
import '../../chat/widgets/syntax_highlight_view.dart';
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

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      exit(0);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 0.0),
      child: FrostedGlass(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
        borderRadius: BorderRadius.circular(16.0),
        borderColor: appColors.borderSubtle,
        backgroundColor: appColors.sidebar,
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
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sidebarState = ref.watch(sidebarProvider);
    final modelState = ref.watch(modelProvider);
    final chatState = ref.watch(chatProvider);
    final sidebarMode = ref.watch(sidebarModeProvider);
    final workspaceListState = ref.watch(workspaceListProvider);
    final activeWsState = ref.watch(activeWorkspaceProvider);

    final chatNotifier = ref.read(chatProvider.notifier);
    final sidebarNotifier = ref.read(sidebarProvider.notifier);
    final modelNotifier = ref.read(modelProvider.notifier);

    final selectedModel = modelState.selectedModel ??
        (modelState.models.isNotEmpty ? modelState.models.first.name : 'qwen2.5:3b');

    final currentConv = sidebarState.conversations
        .where((c) => c.id == (chatState.conversationId ?? sidebarState.activeConversationId))
        .firstOrNull;
    final isWorkspaceChat = currentConv?.workspaceId != null;
    final currentConvWs = isWorkspaceChat
        ? workspaceListState.workspaces.where((w) => w.id == currentConv!.workspaceId).firstOrNull
        : null;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        // Sidebar toggle (Ctrl+B on Linux/Windows, Cmd+B on Mac)
        SingleActivator(LogicalKeyboardKey.keyB, control: true): _SidebarIntent(),
        SingleActivator(LogicalKeyboardKey.keyB, meta: true): _SidebarIntent(),

        // Quick Switcher / Search (Ctrl+K on Linux/Windows, Cmd+K on Mac)
        SingleActivator(LogicalKeyboardKey.keyK, control: true): _SearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true): _SearchIntent(),

        // New Chat (Ctrl+N on Linux/Windows, Cmd+N on Mac)
        SingleActivator(LogicalKeyboardKey.keyN, control: true): _NewChatIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, meta: true): _NewChatIntent(),

        // Settings (Cmd+, on Mac, Ctrl+, on Linux/Windows)
        SingleActivator(LogicalKeyboardKey.comma, control: true): _SettingsIntent(),
        SingleActivator(LogicalKeyboardKey.comma, meta: true): _SettingsIntent(),

        // Stop generation
        SingleActivator(LogicalKeyboardKey.escape): _StopIntent(),

        // Fullscreen / Zen Mode (F11 on Linux/Windows, Cmd+Ctrl+F on Mac)
        SingleActivator(LogicalKeyboardKey.f11): _ZenModeIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true, meta: true): _ZenModeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SidebarIntent: CallbackAction<_SidebarIntent>(onInvoke: (_) => _toggleSidebar()),
          _SearchIntent: CallbackAction<_SearchIntent>(onInvoke: (_) => _openQuickSwitcher()),
          _NewChatIntent: CallbackAction<_NewChatIntent>(onInvoke: (_) => _newChat()),
          _SettingsIntent: CallbackAction<_SettingsIntent>(onInvoke: (_) => _openSettings()),
          _StopIntent: CallbackAction<_StopIntent>(onInvoke: (_) => chatNotifier.stopGeneration()),
          _ZenModeIntent: CallbackAction<_ZenModeIntent>(onInvoke: (_) => _toggleZenMode()),
        },
        child: FocusScope(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              color: appColors.background.withValues(
                alpha: isDark ? 0.60 : 0.68,
              ),
              child: Column(
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
                          activeConversationId: chatState.conversationId ?? sidebarState.activeConversationId,
                          searchController: _searchController,
                          onSearchChanged: (q) => sidebarNotifier.setSearchQuery(q),
                          onSearchClear: () {
                            _searchController.clear();
                            sidebarNotifier.setSearchQuery('');
                          },
                          onNewChat: _newChat,
                          onSelectChat: (id) {
                            setState(() => _isViewingWorkspaceHub = false);
                            sidebarNotifier.setActiveConversation(id);
                            chatNotifier.loadConversation(id);
                          },
                          onDeleteChat: (id) async {
                            await sidebarNotifier.deleteConversation(id);
                            ref.read(workspaceProvider.notifier).removeConversation(id);
                            ref.read(activeWorkspaceProvider.notifier).refresh();
                            if (chatState.conversationId == id) {
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
                          onExportChat: (_) {},
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
                          isCanvasOpen: chatState.isCanvasOpen,
                          onCloseCanvas: () => chatNotifier.closeCanvas(),
                          language: chatState.canvasLanguage,
                          onCopy: () {
                            if (chatState.canvasContent != null) {
                              Clipboard.setData(ClipboardData(text: chatState.canvasContent!));
                            }
                          },
                          canvasPanel: SelectionArea(
                            child: Container(
                              color: appColors.codeBackground,
                              width: double.infinity,
                              height: double.infinity,
                              padding: const EdgeInsets.all(16.0),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SyntaxHighlightView(
                                    chatState.canvasContent ?? '',
                                    language: chatState.canvasLanguage,
                                    theme: getHighlightCodeTheme(
                                      Theme.of(context).brightness == Brightness.dark,
                                      appColors.textPrimary,
                                    ),
                                    textStyle: AppTypography.code.copyWith(
                                      color: appColors.textPrimary,
                                      fontSize: 13.0,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          chatPanel: Padding(
                            padding: EdgeInsets.fromLTRB(4.0, 10.0, chatState.isCanvasOpen ? 5.0 : 10.0, 12.0),
                            child: _isViewingWorkspaceHub && activeWsState.workspace != null
                                ? FrostedGlass(
                                    borderRadius: BorderRadius.circular(18.0),
                                    borderColor: appColors.borderSubtle,
                                    backgroundColor: appColors.surface,
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
                                    child: FrostedGlass(
                                      borderRadius: BorderRadius.circular(18.0),
                                      borderColor: _isDraggingOverChat ? appColors.accent : appColors.borderSubtle,
                                      backgroundColor: appColors.surface,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Column(
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
                                                      key: ValueKey(chatState.conversationId ?? 'empty_chat'),
                                                      child: ChatViewport(
                                                        messages: chatState.messages,
                                                        isGenerating: chatState.isGenerating,
                                                        modelName: selectedModel,
                                                        statusMessage: chatState.statusMessage,
                                                        statusTokens: chatState.statusTokens,
                                                        bottomPadding: 120.0,
                                                        onRegenerate: () {
                                                          // Regenerate last user turn safely
                                                          final lastUser = chatState.messages.where((m) => m.role == 'user').lastOrNull;
                                                          if (lastUser != null) {
                                                            chatNotifier.sendMessage(lastUser.content, selectedModel);
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            child: ComposerBar(
                                              isGenerating: chatState.isGenerating,
                                              activePersonaName: chatState.activePersonaName,
                                              modelName: selectedModel,
                                              models: modelState.models,
                                              selectedModel: selectedModel,
                                              onModelChanged: (m) {
                                                if (m != null) modelNotifier.selectModel(m);
                                              },
                                              onManageModels: _openModelManager,
                                              mode: chatState.mode,
                                              onModeChanged: (m) => chatNotifier.setMode(m),
                                              onPersonaTap: () {},
                                              onSelectPersona: (persona) => chatNotifier.setPersona(persona),
                                              onSend: (text) => chatNotifier.sendMessage(text, selectedModel),
                                              onStop: () => chatNotifier.stopGeneration(),
                                            ),
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
      ),
    );
  }
}

class _SidebarIntent extends Intent { const _SidebarIntent(); }
class _SearchIntent extends Intent { const _SearchIntent(); }
class _NewChatIntent extends Intent { const _NewChatIntent(); }
class _SettingsIntent extends Intent { const _SettingsIntent(); }
class _StopIntent extends Intent { const _StopIntent(); }
class _ZenModeIntent extends Intent { const _ZenModeIntent(); }
