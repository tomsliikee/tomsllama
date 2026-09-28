import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';

class TelemetryFooter extends StatefulWidget {
  final int tokens;
  final int durationMs;
  final String modelName;
  final VoidCallback? onRegenerate;
  final String contentToCopy;

  const TelemetryFooter({
    super.key,
    required this.tokens,
    required this.durationMs,
    required this.modelName,
    this.onRegenerate,
    required this.contentToCopy,
  });

  @override
  State<TelemetryFooter> createState() => _TelemetryFooterState();
}

class _TelemetryFooterState extends State<TelemetryFooter> {
  bool _copied = false;

  void _copyContent() async {
    await Clipboard.setData(ClipboardData(text: widget.contentToCopy));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    
    final durationSecs = widget.durationMs / 1000.0;
    final tokensPerSec = widget.durationMs > 0 ? (widget.tokens / durationSecs).toStringAsFixed(1) : '0.0';
    
    final metricsText = '${widget.modelName} · $tokensPerSec tok/s · ${widget.tokens} tokens · ${durationSecs.toStringAsFixed(1)}s TTFT';
    
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 6.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            metricsText,
            style: AppTypography.telemetry.copyWith(
              color: appColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          Text(
            '·',
            style: TextStyle(color: appColors.textSecondary.withValues(alpha: 0.6)),
          ),
          _ActionLink(
            label: I18n.regenerate,
            onTap: widget.onRegenerate,
            appColors: appColors,
          ),
          Text(
            '·',
            style: TextStyle(color: appColors.textSecondary.withValues(alpha: 0.6)),
          ),
          _ActionLink(
            label: _copied ? I18n.copied : I18n.copyMd,
            onTap: _copyContent,
            appColors: appColors,
            colorOverride: _copied ? Colors.green : null,
          ),
        ],
      ),
    );
  }
}

class _ActionLink extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final AppThemeExtension appColors;
  final Color? colorOverride;

  const _ActionLink({
    required this.label,
    this.onTap,
    required this.appColors,
    this.colorOverride,
  });

  @override
  State<_ActionLink> createState() => _ActionLinkState();
}

class _ActionLinkState extends State<_ActionLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final defaultColor = widget.colorOverride ?? widget.appColors.textSecondary;
    final hoverColor = widget.colorOverride ?? widget.appColors.accent;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: AppTypography.uiControl.copyWith(
            color: _isHovered ? hoverColor : defaultColor,
            fontSize: 12.0,
          ),
        ),
      ),
    );
  }
}
