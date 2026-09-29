import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';
import '../../shell/widgets/tomsllama_logo.dart';

class ClaudeThinkingIndicator extends StatefulWidget {
  const ClaudeThinkingIndicator({super.key});

  @override
  State<ClaudeThinkingIndicator> createState() => _ClaudeThinkingIndicatorState();
}

class _ClaudeThinkingIndicatorState extends State<ClaudeThinkingIndicator> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (timer) {
      if (mounted) {
        setState(() {
          final phrases = I18n.thinkingPhrases;
          _currentIndex = (_currentIndex + 1) % phrases.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final phrases = I18n.thinkingPhrases;
    final currentPhrase = phrases[_currentIndex % phrases.length];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: appColors.borderSubtle,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TomsllamaLogo(size: 14.0, animate: true),
          const SizedBox(width: 8.0),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Text(
              currentPhrase,
              key: ValueKey<String>(currentPhrase),
              style: AppTypography.code.copyWith(
                color: appColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
