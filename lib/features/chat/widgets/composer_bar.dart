import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../../../core/models/persona.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/utils/file_utils.dart';

class ComposerBar extends StatefulWidget {
  final bool isGenerating;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final String activePersonaName;
  final VoidCallback onPersonaTap;
  final ValueChanged<String>? onSelectPersona;
  final String? modelName;

  const ComposerBar({
    super.key,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
    required this.activePersonaName,
    required this.onPersonaTap,
    this.onSelectPersona,
    this.modelName,
  });

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isDragging = false;
  bool _hasText = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _focusNode.onKeyEvent = (node, event) => _onKeyEvent(event);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (_hasText != hasText && mounted) {
      setState(() => _hasText = hasText);
    }
  }

  void _onFocusChanged() {
    if (_isFocused != _focusNode.hasFocus && mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                               HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
        if (!isShiftPressed) {
          _handleSend();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    for (final file in details.files) {
      final markdown = await FileUtils.readFileAsMarkdown(file.path);
      if (!mounted) return;
      if (markdown != null) {
        final currentText = _controller.text;
        final selection = _controller.selection;
        
        if (selection.isValid) {
          final newText = currentText.replaceRange(selection.start, selection.end, markdown);
          _controller.text = newText;
          _controller.selection = TextSelection.collapsed(offset: selection.start + markdown.length);
        } else {
          _controller.text = currentText + markdown;
          _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
          child: DropTarget(
            onDragEntered: (_) => setState(() => _isDragging = true),
            onDragExited: (_) => setState(() => _isDragging = false),
            onDragDone: (details) {
              setState(() => _isDragging = false);
              _handleDrop(details);
            },
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: appColors.surface, // #FFFFFF in Claude and Pond
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: (_isFocused || _isDragging) ? appColors.accent : appColors.borderSubtle,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: isDark ? 16.0 : 12.0,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.20)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4.0,
                    offset: const Offset(0, 1),
                  ),
                  if (_isFocused)
                    BoxShadow(
                      color: appColors.accentSubtle,
                      spreadRadius: 2.0,
                      blurRadius: 0.0,
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Text Input
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 12,
                    minLines: 2,
                    textInputAction: TextInputAction.newline,
                    style: AppTypography.uiControl.copyWith(
                      color: appColors.textPrimary,
                      fontSize: 15.0,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: _isDragging
                          ? (I18n.isGerman ? 'Datei hier ablegen...' : 'Drop file here...')
                          : I18n.composerPlaceholder(widget.modelName ?? "qwen2.5:3b"),
                      hintStyle: AppTypography.uiControl.copyWith(
                        color: appColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: 14.0,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  
                  const SizedBox(height: 10.0),

                  // Bottom Bar: Persona Chip & Send Button (1:1 style_preview.html)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Persona Chip
                      _PersonaChip(
                        personaName: widget.activePersonaName,
                        onTap: widget.onPersonaTap,
                        onSelectPersona: widget.onSelectPersona,
                      ),
                      
                      // Send Button
                      _SendButton(
                        isGenerating: widget.isGenerating,
                        hasText: _hasText,
                        onTap: widget.isGenerating ? widget.onStop : (_hasText ? _handleSend : null),
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

class _PersonaChip extends StatefulWidget {
  final String personaName;
  final VoidCallback onTap;
  final ValueChanged<String>? onSelectPersona;

  const _PersonaChip({
    required this.personaName,
    required this.onTap,
    this.onSelectPersona,
  });

  @override
  State<_PersonaChip> createState() => _PersonaChipState();
}

class _PersonaChipState extends State<_PersonaChip> {
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

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissPersonaDialog',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        return Stack(
          children: [
            Positioned(
              left: targetOffset.dx,
              bottom: overlay.size.height - targetOffset.dy + 8.0,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 310.0,
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: appColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18.0,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        child: Text(
                          'ROLLE & HAUPTPROMPT',
                          style: AppTypography.uiControl.copyWith(
                            color: appColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      ...Persona.defaultPersonas.map((p) {
                        final isCurrent = p.name.toLowerCase() == widget.personaName.toLowerCase();
                        return InkWell(
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            widget.onSelectPersona?.call(p.name);
                            widget.onTap();
                          },
                          borderRadius: BorderRadius.circular(10.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                            decoration: BoxDecoration(
                              color: isCurrent ? appColors.accentSubtle : Colors.transparent,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Row(
                              children: [
                                if (isCurrent)
                                  Icon(Icons.check, size: 14.0, color: appColors.accent)
                                else
                                  const SizedBox(width: 14.0),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: AppTypography.uiControl.copyWith(
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
                                          style: AppTypography.uiControl.copyWith(
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
                      }),
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
          decoration: BoxDecoration(
            color: appColors.background,
            border: Border.all(
              color: _isHovered ? appColors.accent : appColors.borderSubtle,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                I18n.roleLabel,
                style: AppTypography.uiControl.copyWith(
                  color: _isHovered ? appColors.accent : appColors.textSecondary,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                widget.personaName,
                style: AppTypography.uiControl.copyWith(
                  color: _isHovered ? appColors.accent : appColors.textSecondary,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4.0),
              Icon(
                Icons.keyboard_arrow_up,
                size: 13.0,
                color: _isHovered ? appColors.accent : appColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final bool isGenerating;
  final bool hasText;
  final VoidCallback? onTap;

  const _SendButton({
    required this.isGenerating,
    required this.hasText,
    required this.onTap,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    final bgColor = widget.isGenerating
        ? appColors.surface
        : appColors.accent;

    final textColor = widget.isGenerating
        ? appColors.textPrimary
        : Colors.white;

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: const Cubic(0.34, 1.56, 0.64, 1),
          child: Opacity(
            opacity: widget.hasText || widget.isGenerating ? 1.0 : 0.6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7.0),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16.0),
                border: widget.isGenerating ? Border.all(color: appColors.borderSubtle) : null,
              ),
              child: Text(
                widget.isGenerating ? I18n.stop : I18n.send,
                style: AppTypography.uiControl.copyWith(
                  color: textColor,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
