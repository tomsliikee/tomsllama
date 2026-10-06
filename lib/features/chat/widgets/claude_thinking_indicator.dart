import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';
import '../../shell/widgets/tomsllama_logo.dart';

class ClaudeThinkingIndicator extends StatefulWidget {
  final String? statusMessage;
  final int? totalTokens;

  const ClaudeThinkingIndicator({
    super.key,
    this.statusMessage,
    this.totalTokens,
  });

  @override
  State<ClaudeThinkingIndicator> createState() => _ClaudeThinkingIndicatorState();
}

class _ClaudeThinkingIndicatorState extends State<ClaudeThinkingIndicator> {
  int _currentIndex = 0;
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
          if (_elapsedSeconds % 3 == 0) {
            final phrases = I18n.thinkingPhrases;
            _currentIndex = (_currentIndex + 1) % phrases.length;
          }
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
    String activeText;
    if (widget.statusMessage?.trim().isNotEmpty == true) {
      final base = widget.statusMessage!.trim();
      final tokens = widget.totalTokens;
      if (tokens != null && tokens > 500) {
        final expectedSeconds = (tokens / 38).round();
        final remainingSeconds = (expectedSeconds - _elapsedSeconds).clamp(0, 9999);
        final remainingStr = remainingSeconds >= 60
            ? '${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')} Min'
            : '${remainingSeconds}s';
        final tokenStr = tokens >= 1000
            ? '~${(tokens / 1000).toStringAsFixed(1)}k'
            : '~$tokens';

        if (remainingSeconds > 0) {
          activeText = I18n.cpuEvaluatingContext(tokenStr, remainingStr);
        } else {
          activeText = I18n.cpuFinalizingContext(tokenStr, _elapsedSeconds);
        }
      } else if (base.endsWith('...')) {
        final prefix = base.substring(0, base.length - 3);
        activeText = '$prefix, ${_elapsedSeconds}s)...';
      } else {
        activeText = '$base (${_elapsedSeconds}s)';
      }
    } else {
      activeText = phrases[_currentIndex % phrases.length];
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
      decoration: BoxDecoration(
        color: appColors.background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: appColors.borderSubtle,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TomsllamaLogo(size: 13.0, breathing: true),
          const SizedBox(width: 7.0),
          AnimatedSwitcher(
            duration: AppMotion.base,
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: AppMotion.standard)),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Text(
              activeText,
              key: ValueKey<String>(activeText),
              style: AppTypography.code.copyWith(
                color: appColors.textSecondary,
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
