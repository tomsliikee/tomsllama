import 'package:flutter/material.dart';
import '../constants/app_tokens.dart';
import '../constants/app_icons.dart';
import '../constants/app_typography.dart';
import '../models/persona.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';

class PersonaChip extends StatefulWidget {
  final String personaName;
  final VoidCallback onTap;
  final ValueChanged<String>? onSelectPersona;

  const PersonaChip({
    super.key,
    required this.personaName,
    required this.onTap,
    this.onSelectPersona,
  });

  @override
  State<PersonaChip> createState() => _PersonaChipState();
}

class _PersonaChipState extends State<PersonaChip> {
  final GlobalKey _chipKey = GlobalKey();
  bool _isHovered = false;

  void _showPersonaMenu(BuildContext context, AppThemeExtension appColors) async {
    final renderBox = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      widget.onTap();
      return;
    }
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      widget.onTap();
      return;
    }

    final targetOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final ScrollController scrollController = ScrollController();

    // Primary roles
    const primaryOrder = ['standard', 'coder', 'security', 'planner', 'marketing'];
    final primaryPersonas = <Persona>[];
    for (final id in primaryOrder) {
      final match = Persona.defaultPersonas.where((p) => p.id == id);
      if (match.isNotEmpty) primaryPersonas.add(match.first);
    }

    // Additional roles
    const additionalOrder = ['analyst', 'writer', 'architect', 'social_media', 'creative_writer'];
    final additionalPersonas = <Persona>[];
    for (final id in additionalOrder) {
      final match = Persona.defaultPersonas.where((p) => p.id == id);
      if (match.isNotEmpty) additionalPersonas.add(match.first);
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    final double listHeight = (screenHeight * 0.30).clamp(165.0, 225.0);
    const menuWidth = 295.0;

    // Determine whether to open upward or downward based on available screen space
    final availableBelow = overlay.size.height - (targetOffset.dy + renderBox.size.height);
    final openUpwards = availableBelow < (listHeight + 70.0);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissPersonaDialog',
      barrierColor: Colors.transparent,
      transitionDuration: AppMotion.base,
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0.0, openUpwards ? 0.05 : -0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: AppMotion.standard)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        return Stack(
          children: [
            Positioned(
              left: (targetOffset.dx).clamp(8.0, overlay.size.width - menuWidth - 8.0),
              top: openUpwards ? null : targetOffset.dy + renderBox.size.height + 6.0,
              bottom: openUpwards ? (overlay.size.height - targetOffset.dy + 6.0) : null,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: menuWidth,
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: appColors.borderSubtle, width: 1.0),
                    boxShadow: AppElevation.floating(Theme.of(context).brightness),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        child: Text(
                          I18n.roleAndPrompt,
                          style: AppTypography.label.copyWith(
                            color: appColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      SizedBox(
                        height: listHeight,
                        child: Scrollbar(
                          controller: scrollController,
                          thumbVisibility: true,
                          thickness: 3.5,
                          radius: const Radius.circular(AppRadii.control),
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.only(right: 6.0),
                            children: [
                              ...primaryPersonas.map((p) => _buildPersonaItem(p, dialogContext, appColors)),
                              Padding(
                                padding: const EdgeInsets.only(left: 10.0, top: 8.0, bottom: 4.0, right: 6.0),
                                child: Row(
                                  children: [
                                    Text(
                                      I18n.additionalRoles,
                                      style: AppTypography.label.copyWith(
                                        color: appColors.textSecondary.withValues(alpha: 0.65),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    Expanded(
                                      child: Container(
                                        height: 1.0,
                                        color: appColors.borderSubtle.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...additionalPersonas.map((p) => _buildPersonaItem(p, dialogContext, appColors)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPersonaItem(Persona p, BuildContext dialogContext, AppThemeExtension appColors) {
    final isCurrent = p.name.toLowerCase() == widget.personaName.toLowerCase();
    return InkWell(
      onTap: () {
        Navigator.of(dialogContext).pop();
        widget.onSelectPersona?.call(p.name);
        widget.onTap();
      },
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.5),
        decoration: BoxDecoration(
          color: isCurrent ? appColors.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Row(
          children: [
            if (isCurrent)
              Icon(AppIcons.check, size: 14.0, color: appColors.accent)
            else
              const SizedBox(width: 14.0),
            const SizedBox(width: 8.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: AppTypography.label.copyWith(
                      color: isCurrent ? appColors.accent : appColors.textPrimary,
                      fontSize: 12.0,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (p.description.isNotEmpty)
                    Text(
                      p.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: appColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                ],
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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: _chipKey,
        onTap: () {
          if (widget.onSelectPersona != null) {
            _showPersonaMenu(context, appColors);
          } else {
            widget.onTap();
          }
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
          decoration: BoxDecoration(
            color: appColors.background,
            border: Border.all(
              color: _isHovered ? appColors.accent : appColors.borderSubtle,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                I18n.roleLabel,
                style: AppTypography.label.copyWith(
                  color: _isHovered ? appColors.accent : appColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                widget.personaName,
                style: AppTypography.label.copyWith(
                  color: _isHovered ? appColors.accent : appColors.textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4.0),
              Icon(
                AppIcons.caretDown,
                size: 14.0,
                color: _isHovered ? appColors.accent : appColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
