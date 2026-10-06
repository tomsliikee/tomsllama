import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/widgets/tomsllama_logo.dart';

class ClaudeThinkingIndicator extends StatefulWidget {
  final String? statusMessage;
  final int? totalTokens;

  /// Estimated seconds until the first token, for the countdown.
  final int? etaSeconds;

  const ClaudeThinkingIndicator({
    super.key,
    this.statusMessage,
    this.totalTokens,
    this.etaSeconds,
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
      final eta = widget.etaSeconds;
      String formatRemaining(int seconds) => seconds >= 60
          ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} min'
          : '${seconds}s';

      if (tokens != null && eta != null) {
        // Count down against the estimate made for this prompt on this model.
        final remainingSeconds = (eta - _elapsedSeconds).clamp(0, 9999);
        final tokenStr = tokens >= 1000 ? '~${(tokens / 1000).toStringAsFixed(1)}k' : '~$tokens';
        activeText = remainingSeconds > 0
            ? I18n.evaluatingContext(tokenStr, formatRemaining(remainingSeconds))
            : I18n.finalizingContext(tokenStr, _elapsedSeconds);
      } else if (base.endsWith('...')) {
        final prefix = base.substring(0, base.length - 3);
        final remaining = eta == null ? 0 : (eta - _elapsedSeconds).clamp(0, 9999);
        activeText = remaining > 0
            ? '$prefix (${_elapsedSeconds}s • ~${formatRemaining(remaining)})...'
            : '$prefix (${_elapsedSeconds}s)...';
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
