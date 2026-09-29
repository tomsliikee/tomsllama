import 'package:flutter/material.dart';
import '../../../core/models/conversation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';

/// Tactile wobble / jiggle animation wrapper for items during drag-and-drop
class WobbleItem extends StatefulWidget {
  final Widget child;
  final bool isWobbling;
  final int index;

  const WobbleItem({
    super.key,
    required this.child,
    required this.isWobbling,
    this.index = 0,
  });

  @override
  State<WobbleItem> createState() => _WobbleItemState();
}

class _WobbleItemState extends State<WobbleItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Slightly different period per item for organic, non-uniform jiggle
    final periodMs = 120 + (widget.index % 4) * 15;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: periodMs),
    );

    // Alternate initial direction based on parity for tactile feel
    final double maxAngle = (widget.index.isEven ? 1.0 : -1.0) * 0.016; // ~0.9 degrees
    _animation = Tween<double>(begin: -maxAngle, end: maxAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    if (widget.isWobbling) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(WobbleItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWobbling != oldWidget.isWobbling) {
      if (widget.isWobbling) {
        _controller.repeat(reverse: true);
      } else {
        _controller.animateTo(0.5, duration: const Duration(milliseconds: 60)).then((_) {
          if (mounted && !widget.isWobbling) {
            _controller.stop();
            _controller.value = 0.5;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isWobbling) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ChatListItem extends StatefulWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePin;
  final VoidCallback? onExport;
  final int index;
  final bool isWobbling;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
    this.onTogglePin,
    this.onExport,
    this.index = 0,
    this.isWobbling = false,
  });

  @override
  State<ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<ChatListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isPinned = widget.conversation.isPinned;
    final showActions = _isHovered || widget.isSelected || isPinned;

    return WobbleItem(
      isWobbling: widget.isWobbling,
      index: widget.index,
      child: ReorderableDelayedDragStartListener(
        index: widget.index,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(bottom: 2.0),
              padding: EdgeInsets.only(
                left: widget.isSelected ? 10.0 : (_isHovered ? 11.0 : 10.0),
                right: 8.0,
                top: 7.0,
                bottom: 7.0,
              ),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? appColors.surface
                    : (_isHovered ? appColors.hover : Colors.transparent),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: widget.isSelected ? appColors.borderSubtle : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  // Title text
                  Expanded(
                    child: Text(
                      widget.conversation.title.isEmpty ? I18n.newChatTitle : widget.conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.uiControl.copyWith(
                        color: widget.isSelected
                            ? appColors.textPrimary
                            : (isPinned ? appColors.textPrimary : appColors.textSecondary),
                        fontWeight: (widget.isSelected || isPinned)
                            ? FontWeight.w500
                            : FontWeight.w400,
                        fontSize: 13.0,
                      ),
                    ),
                  ),

                  // Actions row: Pin button next to Delete ('X') button + Drag handle
                  if (showActions)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pin button
                        if (widget.onTogglePin != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 3.0),
                            child: InkWell(
                              onTap: widget.onTogglePin,
                              borderRadius: BorderRadius.circular(6.0),
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Icon(
                                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                  size: 13.0,
                                  color: isPinned ? appColors.accent : appColors.textSecondary,
                                ),
                              ),
                            ),
                          ),

                        // Delete button ('X')
                        if (widget.onDelete != null && (_isHovered || widget.isSelected))
                          Padding(
                            padding: const EdgeInsets.only(left: 3.0),
                            child: InkWell(
                              onTap: widget.onDelete,
                              borderRadius: BorderRadius.circular(6.0),
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 13.0,
                                  color: appColors.textSecondary,
                                ),
                              ),
                            ),
                          ),

                        // Instant Drag Handle on Hover
                        if (_isHovered)
                          ReorderableDragStartListener(
                            index: widget.index,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 3.0),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.grab,
                                child: Padding(
                                  padding: const EdgeInsets.all(3.0),
                                  child: Icon(
                                    Icons.drag_indicator_rounded,
                                    size: 13.0,
                                    color: appColors.textSecondary.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
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
