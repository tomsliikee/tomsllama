import 'package:flutter/material.dart';
import '../../../core/models/workspace.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';
import 'chat_list_item.dart';

class WorkspaceListItem extends StatefulWidget {
  final Workspace workspace;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePin;
  final int index;
  final bool isWobbling;

  const WorkspaceListItem({
    super.key,
    required this.workspace,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
    this.onTogglePin,
    this.index = 0,
    this.isWobbling = false,
  });

  @override
  State<WorkspaceListItem> createState() => _WorkspaceListItemState();
}

class _WorkspaceListItemState extends State<WorkspaceListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    final itemWidget = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? appColors.accentSubtle
                : (_isHovered ? appColors.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color: widget.isSelected
                  ? appColors.accent.withValues(alpha: 0.3)
                  : (_isHovered ? appColors.borderSubtle : Colors.transparent),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 14.0,
                color: widget.isSelected
                    ? appColors.accent
                    : (_isHovered ? appColors.textPrimary : appColors.textSecondary),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  widget.workspace.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.uiControl.copyWith(
                    color: widget.isSelected
                        ? appColors.textPrimary
                        : (_isHovered ? appColors.textPrimary : appColors.textSecondary),
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13.0,
                  ),
                ),
              ),
              if (widget.workspace.isPinned)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Icon(
                    Icons.push_pin,
                    size: 12.0,
                    color: appColors.accent,
                  ),
                ),
              if (_isHovered) ...[
                const SizedBox(width: 4.0),
                if (widget.onTogglePin != null)
                  _buildActionBtn(
                    icon: widget.workspace.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    tooltip: widget.workspace.isPinned ? 'Pin lösen' : 'Pinnen',
                    onTap: widget.onTogglePin!,
                    appColors: appColors,
                    color: widget.workspace.isPinned ? appColors.accent : null,
                  ),
                if (widget.onDelete != null)
                  _buildActionBtn(
                    icon: Icons.delete_outline,
                    tooltip: I18n.deleteChatConfirm,
                    onTap: () => _confirmDelete(context),
                    appColors: appColors,
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    return WobbleItem(
      isWobbling: widget.isWobbling,
      index: widget.index,
      child: itemWidget,
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required AppThemeExtension appColors,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4.0),
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: Icon(
            icon,
            size: 13.0,
            color: color ?? appColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final appColors = context.appColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: appColors.borderSubtle, width: 1.0),
        ),
        title: Text(
          I18n.deleteWorkspaceConfirm,
          style: AppTypography.headline.copyWith(fontSize: 16.0, color: appColors.textPrimary),
        ),
        content: Text(
          'Möchtest du den Workspace "${widget.workspace.name}" und alle zugehörigen Chats und Dateien wirklich löschen?',
          style: AppTypography.uiControl.copyWith(fontSize: 13.0, color: appColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              I18n.close,
              style: AppTypography.uiControl.copyWith(color: appColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onDelete?.call();
            },
            child: Text(
              'Löschen',
              style: AppTypography.uiControl.copyWith(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
