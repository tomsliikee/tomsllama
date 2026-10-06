import 'package:flutter/material.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/models/conversation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/widgets/ink_fade_in.dart';
import '../../../core/widgets/breathing_tint.dart';
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
        _controller.animateTo(0.5, duration: AppMotion.fast).then((_) {
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
  final bool isGenerating;
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
    this.isGenerating = false,
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
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              // A chat with an answer in progress breathes, whether or not it is the open one.
              child: BreathingTint(
                active: widget.isGenerating,
                color: appColors.textPrimary,
                child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              padding: const EdgeInsets.only(left: 10.0, right: 6.0, top: 7.0, bottom: 7.0),
              // The open chat is marked by a soft tint of the text colour and a
              // firmer title, nothing drawn on top of it.
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? appColors.textPrimary.withValues(alpha: 0.07)
                    : (_isHovered ? appColors.hover : Colors.transparent),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Row(
                children: [
                  // Title text
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        widget.conversation.title.isEmpty ? I18n.newChatTitle : widget.conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.small.copyWith(
                          color: (widget.isSelected || isPinned || _isHovered)
                              ? appColors.textPrimary
                              : appColors.textSecondary,
                          fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),

                  // Actions row: Pin button next to Delete ('X') button + Drag handle
                  if (showActions)
                    InkFadeIn(
                      child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pin button
                        if (widget.onTogglePin != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 3.0),
                            child: InkWell(
                              onTap: widget.onTogglePin,
                              borderRadius: BorderRadius.circular(AppRadii.control),
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Icon(
                                  isPinned ? AppIcons.pinned : AppIcons.pin,
                                  size: 14.0,
                                  color: isPinned ? appColors.accent : appColors.textSecondary,
                                ),
                              ),
                            ),
                          ),

                        // Export button
                        if (widget.onExport != null && _isHovered)
                          Padding(
                            padding: const EdgeInsets.only(left: 3.0),
                            child: Tooltip(
                              message: I18n.exportChat,
                              waitDuration: const Duration(milliseconds: 400),
                              child: InkWell(
                                onTap: widget.onExport,
                                borderRadius: BorderRadius.circular(AppRadii.control),
                                child: Padding(
                                  padding: const EdgeInsets.all(3.0),
                                  child: Icon(
                                    AppIcons.export,
                                    size: 14.0,
                                    color: appColors.textSecondary,
                                  ),
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
                              borderRadius: BorderRadius.circular(AppRadii.control),
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Icon(
                                  AppIcons.close,
                                  size: 14.0,
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
                                    AppIcons.dragHandle,
                                    size: 14.0,
                                    color: appColors.textSecondary.withValues(alpha: 0.5),
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
        ),
      ),
    );
  }
}
