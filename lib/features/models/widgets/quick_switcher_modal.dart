import 'package:flutter/material.dart';
import '../../../core/models/conversation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/services/localization_service.dart';

class QuickSwitcherModal extends StatefulWidget {
  final List<Conversation> conversations;
  final ValueChanged<String> onSelect;

  const QuickSwitcherModal({
    super.key,
    required this.conversations,
    required this.onSelect,
  });

  @override
  State<QuickSwitcherModal> createState() => _QuickSwitcherModalState();
}

class _QuickSwitcherModalState extends State<QuickSwitcherModal> {
  final TextEditingController _controller = TextEditingController();
  List<Conversation> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.conversations;
  }

  void _filter(String query) {
    if (query.isEmpty) {
      setState(() => _filtered = widget.conversations);
    } else {
      setState(() {
        _filtered = widget.conversations
            .where((c) => c.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: Container(
        width: 580.0,
        height: 400.0,
        decoration: BoxDecoration(
          color: appColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.panel),
          border: Border.all(color: appColors.border, width: 1.0),
          boxShadow: AppElevation.floating(Theme.of(context).brightness),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // The query line is the dialog's header: no box, just type and a hairline below
            Padding(
              padding: const EdgeInsets.fromLTRB(18.0, 16.0, 18.0, 14.0),
              child: Row(
                children: [
                  Icon(AppIcons.search, size: 17.0, color: appColors.textSecondary),
                  const SizedBox(width: AppSpace.m),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: _filter,
                      autofocus: true,
                      style: AppTypography.input.copyWith(color: appColors.textPrimary, height: 1.3),
                      decoration: InputDecoration(
                        hintText: I18n.quickSearchPlaceholder,
                        hintStyle: AppTypography.input.copyWith(
                          color: appColors.textSecondary.withValues(alpha: 0.7),
                          height: 1.3,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1.0, color: appColors.borderSubtle),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpace.s),
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final c = _filtered[index];
                  return Pressable(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelect(c.id);
                    },
                    builder: (context, isHovered, _) => AnimatedContainer(
                      duration: AppMotion.fast,
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 9.0),
                      decoration: BoxDecoration(
                        color: isHovered ? appColors.accentSubtle : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.title.isEmpty ? I18n.newChatTitle : c.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.small.copyWith(
                                color: isHovered ? appColors.accent : appColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.m),
                          Text(
                            c.updatedAt.toIso8601String().substring(0, 10),
                            style: AppTypography.telemetry.copyWith(color: appColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
