import 'package:flutter/material.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/models/workspace.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/widgets/app_dialog.dart';
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
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          margin: const EdgeInsets.only(bottom: 2.0),
          padding: const EdgeInsets.only(left: 10.0, right: 6.0, top: 8.0, bottom: 8.0),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? appColors.textPrimary.withValues(alpha: 0.07)
                : (_isHovered ? appColors.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.folder,
                size: 14.0,
                color: widget.isSelected
                    ? appColors.textPrimary
                    : (_isHovered ? appColors.textPrimary : appColors.textSecondary),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  widget.workspace.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.small.copyWith(
                    color: widget.isSelected
                        ? appColors.textPrimary
                        : (_isHovered ? appColors.textPrimary : appColors.textSecondary),
                    fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              ),
              if (widget.workspace.isPinned && !_isHovered)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Icon(
                    AppIcons.pinned,
                    size: 13.0,
                    color: appColors.accent,
                  ),
                ),
              if (_isHovered) ...[
                const SizedBox(width: 4.0),
                if (widget.onTogglePin != null)
                  _buildActionBtn(
                    icon: widget.workspace.isPinned ? AppIcons.pinned : AppIcons.pin,
                    tooltip: widget.workspace.isPinned ? 'Pin lösen' : 'Pinnen',
                    onTap: widget.onTogglePin!,
                    appColors: appColors,
                    color: widget.workspace.isPinned ? appColors.accent : null,
                  ),
                if (widget.onDelete != null)
                  _buildActionBtn(
                    icon: AppIcons.close,
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
        borderRadius: BorderRadius.circular(AppRadii.control),
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
      builder: (ctx) => AppDialog(
        title: I18n.deleteWorkspaceConfirm,
        width: 420.0,
        actions: [
          AppButton(label: I18n.cancel, onTap: () => Navigator.of(ctx).pop()),
          AppButton(
            label: I18n.delete,
            isDestructive: true,
            onTap: () {
              Navigator.of(ctx).pop();
              widget.onDelete?.call();
            },
          ),
        ],
        child: Text(
          I18n.deleteWorkspaceConfirmMessage(widget.workspace.name),
          style: AppTypography.small.copyWith(color: appColors.textSecondary, height: 1.45),
        ),
      ),
    );
  }
}
