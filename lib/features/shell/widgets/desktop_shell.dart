import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/database_service.dart';
import '../../sidebar/controllers/sidebar_controller.dart';
import '../../models/controllers/model_controller.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../sidebar/widgets/sidebar_view.dart';
import '../../chat/widgets/chat_viewport.dart';
import '../../chat/widgets/composer_bar.dart';
import '../../chat/widgets/artifact_canvas_view.dart';
import 'csd_header_bar.dart';
import '../../models/widgets/quick_switcher_modal.dart';
import '../../models/widgets/model_manager_dialog.dart';
import '../../settings/widgets/settings_dialog.dart';

class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> with WindowListener {
  bool _isSidebarOpen = true;
  bool _isZenMode = false;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sidebarNotifier = ref.read(sidebarProvider.notifier);
      await sidebarNotifier.loadConversations();
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
    super.dispose();
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
    await ref.read(chatProvider.notifier).startNewChat();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    final sidebarState = ref.watch(sidebarProvider);
    final modelState = ref.watch(modelProvider);
    final chatState = ref.watch(chatProvider);

    final chatNotifier = ref.read(chatProvider.notifier);
    final sidebarNotifier = ref.read(sidebarProvider.notifier);
    final modelNotifier = ref.read(modelProvider.notifier);

    final selectedModel = modelState.selectedModel ??
        (modelState.models.isNotEmpty ? modelState.models.first.name : 'qwen2.5:3b');

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
                  models: modelState.models,
                  selectedModel: selectedModel,
                  onModelChanged: (m) {
                    if (m != null) modelNotifier.selectModel(m);
                  },
                  onManageModels: _openModelManager,
                  temperature: chatState.temperature,
                  onTemperatureChanged: (temp) => chatNotifier.setTemperature(temp),
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
                            sidebarNotifier.setActiveConversation(id);
                            chatNotifier.loadConversation(id);
                          },
                          onDeleteChat: (id) async {
                            await sidebarNotifier.deleteConversation(id);
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
                          onExportChat: (_) {},
                        ),
                      
                      // Main Chat & Split-View Canvas Area
                      Expanded(
                        child: ArtifactCanvasView(
                          isCanvasOpen: chatState.isCanvasOpen,
                          onCloseCanvas: () => chatNotifier.closeCanvas(),
                          canvasPanel: Container(
                            color: appColors.codeBackground,
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      chatState.canvasLanguage ?? 'code',
                                      style: AppTypography.code.copyWith(
                                        color: appColors.accent,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => chatNotifier.closeCanvas(),
                                      child: Icon(Icons.close, size: 16.0, color: appColors.textSecondary),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24.0),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      chatState.canvasContent ?? '',
                                      style: AppTypography.code.copyWith(
                                        color: appColors.textPrimary,
                                        fontSize: 13.0,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          chatPanel: Padding(
                            padding: const EdgeInsets.fromLTRB(4.0, 10.0, 10.0, 12.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: appColors.surface,
                                borderRadius: BorderRadius.circular(18.0),
                                border: Border.all(color: appColors.borderSubtle, width: 1.0),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
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
                                  ComposerBar(
                                    isGenerating: chatState.isGenerating,
                                    activePersonaName: chatState.activePersonaName,
                                    modelName: selectedModel,
                                    onPersonaTap: () {},
                                    onSelectPersona: (persona) => chatNotifier.setPersona(persona),
                                    onSend: (text) => chatNotifier.sendMessage(text, selectedModel),
                                    onStop: () => chatNotifier.stopGeneration(),
                                  ),
                                ],
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
