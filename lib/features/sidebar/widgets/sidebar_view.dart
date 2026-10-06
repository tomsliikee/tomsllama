import 'package:flutter/material.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/models/conversation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/models/workspace.dart';
import '../../workspace/controllers/workspace_hub_controller.dart';
import '../../shell/widgets/tomsllama_logo.dart';
import 'chat_list_item.dart';
import 'search_bar_view.dart';
import 'workspace_list_item.dart';

class SidebarView extends StatefulWidget {
  final List<Conversation> conversations;
  final String? activeConversationId;
  final Set<String> generatingConversationIds;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectChat;
  final ValueChanged<String>? onDeleteChat;
  final ValueChanged<String>? onTogglePinChat;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final ValueChanged<String>? onExportChat;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;

  // Workspace integration
  final SidebarMode mode;
  final ValueChanged<SidebarMode>? onModeChanged;
  final List<Workspace> workspaces;
  final String? activeWorkspaceId;
  final ValueChanged<String>? onSelectWorkspace;
  final VoidCallback? onNewWorkspace;
  final ValueChanged<String>? onDeleteWorkspace;
  final ValueChanged<String>? onTogglePinWorkspace;
  final void Function(int oldIndex, int newIndex)? onReorderWorkspaces;

  const SidebarView({
    super.key,
    required this.conversations,
    this.activeConversationId,
    this.generatingConversationIds = const {},
    required this.onNewChat,
    required this.onSelectChat,
    this.onDeleteChat,
    this.onTogglePinChat,
    this.onReorder,
    this.onExportChat,
    this.searchController,
    this.onSearchChanged,
    this.onSearchClear,
    this.mode = SidebarMode.chats,
    this.onModeChanged,
    this.workspaces = const [],
    this.activeWorkspaceId,
    this.onSelectWorkspace,
    this.onNewWorkspace,
    this.onDeleteWorkspace,
    this.onTogglePinWorkspace,
    this.onReorderWorkspaces,
  });

  @override
  State<SidebarView> createState() => _SidebarViewState();
}

class _SidebarViewState extends State<SidebarView> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Container(
      width: 260.0,
      padding: const EdgeInsets.only(left: 12.0, top: 10.0, bottom: 12.0, right: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Floating Pills: Large Logo Pill + New Action Pill
          Row(
            children: [
              // Large Logo Pill
              const _LogoFloatingPill(),
              const SizedBox(width: 8.0),
              // Separated New Action Floating Pill (+ Neuer Chat / + Neuer Workspace)
              Expanded(
                child: _NewActionButton(
                  mode: widget.mode,
                  onTap: widget.mode == SidebarMode.chats
                      ? widget.onNewChat
                      : () => widget.onNewWorkspace?.call(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8.0),

          // Sliding Segmented Control (Chats vs Workspaces)
          _buildModeSlider(appColors),

          const SizedBox(height: 8.0),

          if (widget.searchController != null) ...[
            SearchBarView(
              controller: widget.searchController!,
              onChanged: (q) => widget.onSearchChanged?.call(q),
              onClear: () => widget.onSearchClear?.call(),
            ),
            const SizedBox(height: 8.0),
          ],

          // Content Floating Pill Panel (Chats OR Workspaces)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: appColors.sidebar,
                borderRadius: BorderRadius.circular(AppRadii.panel),
                border: Border.all(color: appColors.borderSubtle, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    child: Text(
                      widget.mode == SidebarMode.chats ? I18n.history : I18n.workspaces.toUpperCase(),
                      style: AppTypography.micro.copyWith(color: appColors.textSecondary),
                    ),
                  ),

                  const SizedBox(height: 6.0),

                  // Content List (Chats or Workspaces)
                  Expanded(
                    child: widget.mode == SidebarMode.chats
                        ? _buildChatsList(appColors)
                        : _buildWorkspacesList(appColors),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSlider(AppThemeExtension appColors) {
    const double tabHeight = 32.0;
    final bool isChats = widget.mode == SidebarMode.chats;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Darker selected pill to cleanly contrast against the track in both light and dark mode
    final Color activeIndicatorColor = isDark
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.45), appColors.surface)
        : Color.alphaBlend(appColors.textPrimary.withValues(alpha: 0.07), appColors.surface);

    final Color activeIndicatorBorder = isDark ? appColors.border : appColors.border;

    return Container(
      height: tabHeight,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: appColors.borderSubtle, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double halfWidth = (constraints.maxWidth) / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.slow,
                curve: AppMotion.standard,
                left: isChats ? 0 : halfWidth,
                top: 0,
                bottom: 0,
                width: halfWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: activeIndicatorColor,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(color: activeIndicatorBorder, width: 1.0),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => widget.onModeChanged?.call(SidebarMode.chats),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.chats,
                              size: 13.0,
                              color: isChats ? appColors.textPrimary : appColors.textSecondary,
                            ),
                            const SizedBox(width: 4.0),
                            Flexible(
                              child: Text(
                                I18n.chats,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label.copyWith(
                                  color: isChats ? appColors.textPrimary : appColors.textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: isChats ? FontWeight.w500 : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => widget.onModeChanged?.call(SidebarMode.workspaces),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.folder,
                              size: 13.0,
                              color: !isChats ? appColors.textPrimary : appColors.textSecondary,
                            ),
                            const SizedBox(width: 4.0),
                            Flexible(
                              child: Text(
                                I18n.workspaces,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label.copyWith(
                                  color: !isChats ? appColors.textPrimary : appColors.textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: !isChats ? FontWeight.w500 : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChatsList(AppThemeExtension appColors) {
    if (widget.conversations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          I18n.noChats,
          style: AppTypography.label.copyWith(
            color: appColors.textSecondary,
            fontSize: 12.0,
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: widget.conversations.length,
      onReorderStart: (index) => setState(() => _isDragging = true),
      onReorderEnd: (index) => setState(() => _isDragging = false),
      onReorderItem: (oldIndex, newIndex) => widget.onReorder?.call(oldIndex, newIndex),
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          child: WobbleItem(
            isWobbling: true,
            index: index,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.control),
                boxShadow: AppElevation.floating(Theme.of(context).brightness),
              ),
              child: child,
            ),
          ),
        );
      },
      itemBuilder: (context, index) {
        final c = widget.conversations[index];
        return ChatListItem(
          key: ValueKey(c.id),
          conversation: c,
          index: index,
          isWobbling: _isDragging,
          isSelected: c.id == widget.activeConversationId,
          isGenerating: widget.generatingConversationIds.contains(c.id),
          onTap: () => widget.onSelectChat(c.id),
          onTogglePin: widget.onTogglePinChat != null
              ? () => widget.onTogglePinChat!(c.id)
              : null,
          onDelete: widget.onDeleteChat != null
              ? () => widget.onDeleteChat!(c.id)
              : null,
          onExport: widget.onExportChat != null
              ? () => widget.onExportChat!(c.id)
              : null,
        );
      },
    );
  }

  Widget _buildWorkspacesList(AppThemeExtension appColors) {
    if (widget.workspaces.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          I18n.noWorkspaces,
          style: AppTypography.label.copyWith(
            color: appColors.textSecondary,
            fontSize: 12.0,
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: widget.workspaces.length,
      onReorderStart: (index) => setState(() => _isDragging = true),
      onReorderEnd: (index) => setState(() => _isDragging = false),
      onReorderItem: (oldIndex, newIndex) => widget.onReorderWorkspaces?.call(oldIndex, newIndex),
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          child: WobbleItem(
            isWobbling: true,
            index: index,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.control),
                boxShadow: AppElevation.floating(Theme.of(context).brightness),
              ),
              child: child,
            ),
          ),
        );
      },
      itemBuilder: (context, index) {
        final w = widget.workspaces[index];
        return WorkspaceListItem(
          key: ValueKey(w.id),
          workspace: w,
          index: index,
          isWobbling: _isDragging,
          isSelected: w.id == widget.activeWorkspaceId,
          onTap: () => widget.onSelectWorkspace?.call(w.id),
          onTogglePin: widget.onTogglePinWorkspace != null
              ? () => widget.onTogglePinWorkspace!(w.id)
              : null,
          onDelete: widget.onDeleteWorkspace != null
              ? () => widget.onDeleteWorkspace!(w.id)
              : null,
        );
      },
    );
  }
}

class _LogoFloatingPill extends StatelessWidget {
  const _LogoFloatingPill();

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: appColors.borderSubtle, width: 1.0),
      ),
      child: const TomsllamaLogo(size: 24.0, animate: false),
    );
  }
}

class _NewActionButton extends StatelessWidget {
  final SidebarMode mode;
  final VoidCallback onTap;

  const _NewActionButton({
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isChats = mode == SidebarMode.chats;

    return Pressable(
      onTap: onTap,
      builder: (context, isHovered, _) => AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        height: 42.0,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          color: isHovered ? appColors.accentSubtle : appColors.surface,
          border: Border.all(
            color: isHovered ? appColors.accent.withValues(alpha: 0.35) : appColors.borderSubtle,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          children: [
            Icon(AppIcons.add, size: 14.0, color: isHovered ? appColors.accent : appColors.textSecondary),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                (isChats ? I18n.newChat : I18n.newWorkspace).replaceFirst(RegExp(r'^\+\s*'), ''),
                overflow: TextOverflow.ellipsis,
                style: AppTypography.small.copyWith(
                  color: isHovered ? appColors.accent : appColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
            if (isChats)
              Text(
                I18n.ctrlN,
                style: AppTypography.telemetry.copyWith(
                  color: appColors.textSecondary.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
