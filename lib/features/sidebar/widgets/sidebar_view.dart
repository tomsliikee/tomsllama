import 'package:flutter/material.dart';
import '../../../core/models/conversation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';
import '../../shell/widgets/tomsllama_logo.dart';
import 'chat_list_item.dart';

class SidebarView extends StatefulWidget {
  final List<Conversation> conversations;
  final String? activeConversationId;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectChat;
  final ValueChanged<String>? onDeleteChat;
  final ValueChanged<String>? onTogglePinChat;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final ValueChanged<String>? onExportChat;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;

  const SidebarView({
    super.key,
    required this.conversations,
    this.activeConversationId,
    required this.onNewChat,
    required this.onSelectChat,
    this.onDeleteChat,
    this.onTogglePinChat,
    this.onReorder,
    this.onExportChat,
    this.searchController,
    this.onSearchChanged,
    this.onSearchClear,
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
          // Top Floating Pills: Large Logo Pill + New Chat Pill
          Row(
            children: [
              // Large Logo Pill
              const _LogoFloatingPill(),
              const SizedBox(width: 8.0),
              // Separated New Chat Floating Pill
              Expanded(
                child: _NewChatButton(onTap: widget.onNewChat),
              ),
            ],
          ),

          const SizedBox(height: 10.0),

          // Chat History Floating Pill Panel
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: appColors.sidebar,
                borderRadius: BorderRadius.circular(18.0),
                border: Border.all(color: appColors.borderSubtle, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // VERLAUF / HISTORY Section Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    child: Text(
                      I18n.history,
                      style: AppTypography.uiControl.copyWith(
                        color: appColors.textSecondary,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6.0),

                  // Chat History List with Reorderable Drag-and-Drop and Tactile Jiggle Animation
                  Expanded(
                    child: widget.conversations.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              I18n.noChats,
                              style: AppTypography.uiControl.copyWith(
                                color: appColors.textSecondary,
                                fontSize: 12.0,
                              ),
                            ),
                          )
                        : ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: widget.conversations.length,
                            onReorderStart: (index) {
                              setState(() => _isDragging = true);
                            },
                            onReorderEnd: (index) {
                              setState(() => _isDragging = false);
                            },
                            onReorderItem: (oldIndex, newIndex) {
                              widget.onReorder?.call(oldIndex, newIndex);
                            },
                            proxyDecorator: (child, index, animation) {
                              return Material(
                                color: Colors.transparent,
                                child: WobbleItem(
                                  isWobbling: true,
                                  index: index,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.18),
                                          blurRadius: 14.0,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
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
}

class _LogoFloatingPill extends StatelessWidget {
  const _LogoFloatingPill();

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(8.5),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: appColors.borderSubtle, width: 1.0),
      ),
      child: const TomsllamaLogo(size: 24.0, animate: false),
    );
  }
}

class _NewChatButton extends StatefulWidget {
  final VoidCallback onTap;

  const _NewChatButton({required this.onTap});

  @override
  State<_NewChatButton> createState() => _NewChatButtonState();
}

class _NewChatButtonState extends State<_NewChatButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: const Cubic(0.34, 1.56, 0.64, 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 9.0),
            decoration: BoxDecoration(
              color: appColors.surface,
              border: Border.all(
                color: _isHovered ? appColors.accent : appColors.borderSubtle,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    I18n.newChat,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.uiControl.copyWith(
                      color: _isHovered ? appColors.accent : appColors.textPrimary,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6.0),
                Text(
                  I18n.ctrlN,
                  style: AppTypography.code.copyWith(
                    color: appColors.textSecondary,
                    fontSize: 10.5,
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
