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

    // Just the breathing mark and a line of text: the answer will take this
    // place, so it sits on the page like the answer does, without a frame.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const TomsllamaLogo(size: 15.0, breathing: true),
          const SizedBox(width: 9.0),
          Flexible(
            child: AnimatedSwitcher(
              duration: AppMotion.slow,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previousChildren, if (currentChild != null) currentChild],
              ),
              child: Text(
                activeText,
                key: ValueKey<String>(activeText),
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(color: appColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
