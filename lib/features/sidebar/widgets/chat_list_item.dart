import 'package:flutter/material.dart';
import '../../../core/models/conversation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';

class ChatListItem extends StatefulWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onExport;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
    this.onExport,
  });

  @override
  State<ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<ChatListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return MouseRegion(
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
            left: widget.isSelected ? 10.0 : (_isHovered ? 12.0 : 10.0),
            right: 10.0,
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
              Expanded(
                child: Text(
                  widget.conversation.title.isEmpty ? 'Neuer Chat' : widget.conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.uiControl.copyWith(
                    color: appColors.textPrimary,
                    fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.w400,
                    fontSize: 13.0,
                  ),
                ),
              ),
              if ((_isHovered || widget.isSelected) && widget.onDelete != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: InkWell(
                    onTap: widget.onDelete,
                    borderRadius: BorderRadius.circular(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: Icon(
                        Icons.close,
                        size: 13.0,
                        color: appColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
