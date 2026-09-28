import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';
import 'markdown_view.dart';

class ThinkBlockView extends StatefulWidget {
  final String thinkContent;
  final int durationMs;
  final int tokens;
  final bool isThinking;

  const ThinkBlockView({
    super.key,
    required this.thinkContent,
    this.durationMs = 0,
    this.tokens = 0,
    this.isThinking = false,
  });

  @override
  State<ThinkBlockView> createState() => _ThinkBlockViewState();
}

class _ThinkBlockViewState extends State<ThinkBlockView> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isHovered = false;
  late final AnimationController _animController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isThinking;
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    
    if (_isExpanded) {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ThinkBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isThinking && !oldWidget.isThinking) {
      setState(() => _isExpanded = true);
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final seconds = (widget.durationMs / 1000).toStringAsFixed(1);
    final tokenPart = widget.tokens > 0 ? ' · ${widget.tokens} Tokens' : '';
    final headerLabel = widget.isThinking 
        ? '${I18n.thinkingOngoing} ($seconds s$tokenPart)' 
        : '${I18n.thinkingProcess} ($seconds s$tokenPart)';

    final textColor = _isHovered ? appColors.accent : appColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      decoration: BoxDecoration(
        color: appColors.hover,
        border: Border.all(color: appColors.borderSubtle, width: 1.0),
        borderRadius: BorderRadius.circular(12.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Trigger (1:1 style_preview.html)
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _toggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
                color: Colors.transparent,
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: _isExpanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Text(
                        '▸',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      headerLabel,
                      style: AppTypography.code.copyWith(
                        color: textColor,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Origami Folding Content Area
          SizeTransition(
            sizeFactor: _expandAnimation,
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: appColors.surface, // #FFFFFF in Claude and Pond
                border: Border(
                  top: BorderSide(color: appColors.border, width: 1.0),
                ),
              ),
              child: MarkdownView(
                data: widget.thinkContent,
                isThinkBlock: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
