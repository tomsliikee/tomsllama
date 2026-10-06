import 'package:flutter/material.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/constants/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_typography.dart';
import '../../../core/models/attached_file.dart';
import '../../../core/models/workspace_info.dart';
import '../../../core/models/token_usage_stats.dart';
import '../../../core/services/context_manager.dart';
import '../../../core/services/hardware_calibration_service.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/services/token_stats_service.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/chat_controller.dart';
import '../../models/controllers/model_controller.dart';
import '../../settings/controllers/settings_controller.dart';
import '../../../core/widgets/pressable.dart';

/// An animated extended shelf that slides up from the top edge of the composer
/// with an elastic bounce, displaying Git workspace info, attached files,
/// model timing/mode performance, and daily & total token statistics.
class ComposerShelf extends ConsumerStatefulWidget {
  final bool isExpanded;
  final WorkspaceInfo? workspace;
  final List<AttachedFile> attachedFiles;
  final String? selectedModel;
  final ChatExecutionMode mode;
  final VoidCallback onToggle;

  const ComposerShelf({
    super.key,
    required this.isExpanded,
    required this.workspace,
    required this.attachedFiles,
    required this.selectedModel,
    required this.mode,
    required this.onToggle,
  });

  @override
  ConsumerState<ComposerShelf> createState() => _ComposerShelfState();
}

class _ComposerShelfState extends ConsumerState<ComposerShelf>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _heightAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: widget.isExpanded ? 1.0 : 0.0,
    );

    // Springy elastic bounce curve when opening
    final curvedAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInOutCubic,
    );

    _heightAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnim);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.28),
      end: Offset.zero,
    ).animate(curvedAnim);
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: AppMotion.standard),
    );
  }

  @override
  void didUpdateWidget(covariant ComposerShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isExpanded && _animController.value <= 0.001) {
      return const SizedBox.shrink();
    }
    final appColors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokenStats = ref.watch(tokenStatsProvider);
    final hwCalibration = ref.watch(hardwareCalibrationProvider);

    // What a typical short message costs end to end on the active model: reading
    // ~300 new tokens and writing an answer of the length this model usually gives.
    final modelInfo = ref.watch(modelProvider).models.where((m) => m.name == widget.selectedModel).firstOrNull;
    final baselineEstimate = hwCalibration.estimateResponse(
      uncachedPromptTokens: 300,
      modelName: widget.selectedModel,
      expectsThinking: modelInfo?.supportsThinking == true && widget.mode != ChatExecutionMode.schnell,
    );

    // Shelf background: subtly lighter tone seamlessly extending the composer card
    final Color shelfBg = isDark
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.05), appColors.surface)
        : Color.alphaBlend(Colors.black.withValues(alpha: 0.02), const Color(0xFFF9F9F8));

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        if (_animController.value <= 0.001) {
          return const SizedBox.shrink();
        }

        return ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: _heightAnim.value.clamp(0.0, 1.15),
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 0.0),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: shelfBg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.card),
                    ),
                    border: Border.all(
                      color: appColors.borderSubtle,
                      width: 1.0,
                    ),
                    boxShadow: AppElevation.floating(Theme.of(context).brightness),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: Git Workspace Info & Attached Files
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Git Repository & Branch
                          Expanded(
                            child: _buildWorkspaceSection(appColors),
                          ),
                          const SizedBox(width: 12.0),
                          // Right: Attached Files Summary
                          Expanded(
                            child: _buildFilesSection(appColors),
                          ),
                        ],
                      ),

                      // Divider hairline
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          height: 1.0,
                          color: appColors.borderSubtle.withValues(alpha: 0.5),
                        ),
                      ),

                      // Row 2: Model & Mode Timing + Token Statistics
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Model & Execution Mode Timing
                          Expanded(
                            child: _buildModelTimingSection(
                              appColors: appColors,
                              estimate: baselineEstimate,
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          // Right: Daily & Total Token Consumption
                          Expanded(
                            child: _buildTokenStatsSection(
                              appColors: appColors,
                              tokenStats: tokenStats,
                            ),
                          ),
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          height: 1.0,
                          color: appColors.borderSubtle.withValues(alpha: 0.5),
                        ),
                      ),

                      // Row 3: how full the context window of this chat is
                      _buildContextSection(appColors: appColors, maxContext: modelInfo?.contextLength),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkspaceSection(AppThemeExtension appColors) {
    if (widget.workspace == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.folderOff, size: 13.0, color: appColors.textSecondary),
          const SizedBox(width: 5.0),
          Flexible(
            child: Text(
              I18n.shelfNoWorkspaceActive,
              style: AppTypography.label.copyWith(
                fontSize: 10.5,
                color: appColors.textSecondary.withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final ws = widget.workspace!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.folder, size: 13.5, color: appColors.accent),
        const SizedBox(width: 5.0),
        Flexible(
          child: Text(
            ws.name,
            style: AppTypography.label.copyWith(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: appColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (ws.gitBranch != null && ws.gitBranch!.isNotEmpty) ...[
          const SizedBox(width: 6.0),
          Container(width: 1.0, height: 10.0, color: appColors.borderSubtle),
          const SizedBox(width: 6.0),
          Icon(AppIcons.branch, size: 12.0, color: appColors.textSecondary),
          const SizedBox(width: 3.0),
          Flexible(
            child: Text(
              ws.gitBranch!,
              style: AppTypography.code.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: appColors.accent,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilesSection(AppThemeExtension appColors) {
    if (widget.attachedFiles.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.file, size: 13.0, color: appColors.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(width: 5.0),
          Text(
            I18n.isGerman ? 'Keine Dateien angehängt' : 'No files attached',
            style: AppTypography.label.copyWith(
              fontSize: 10.5,
              color: appColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }

    final totalTokens = widget.attachedFiles.fold<int>(0, (sum, f) => sum + f.estimatedTokens);
    final count = widget.attachedFiles.length;
    final tokenStr = totalTokens >= 1000 ? '~${(totalTokens / 1000).toStringAsFixed(1)}k' : '$totalTokens';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.knowledge, size: 13.5, color: appColors.accent),
        const SizedBox(width: 5.0),
        Flexible(
          child: Text(
            count == 1
                ? '${widget.attachedFiles.first.name} ($tokenStr tok)'
                : '$count ${I18n.isGerman ? 'Dateien' : 'files'} ($tokenStr tok)',
            style: AppTypography.code.copyWith(
              fontSize: 10.5,
              color: appColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildModelTimingSection({
    required AppThemeExtension appColors,
    required ResponseEstimate estimate,
  }) {
    final modelName = widget.selectedModel ?? 'default';
    final modeLabel = _getModeLabel(widget.mode);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.modeFast, size: 13.5, color: appColors.accent),
        const SizedBox(width: 5.0),
        Flexible(
          child: Text(
            estimate.isTested
                ? '$modelName • $modeLabel • ${estimate.durationDisplay} (${estimate.speedDisplay})'
                : '$modelName • $modeLabel • ${estimate.speedDisplay}',
            style: AppTypography.code.copyWith(
              fontSize: 10.5,
              color: appColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static String _compactTokens(int tokens) =>
      tokens >= 1000 ? '${(tokens / 1000).toStringAsFixed(tokens >= 10000 ? 0 : 1)}k' : '$tokens';

  // Window sizes are powers of two: 32768 reads as 32k, not 33k.
  static String _windowSize(int tokens) => tokens % 1024 == 0 ? '${tokens ~/ 1024}k' : _compactTokens(tokens);

  /// Usage of the chat's context window on the selected model. The window comes
  /// from the user's setting and the limit Ollama reports for that model, so it
  /// follows whichever model is picked.
  Widget _buildContextSection({required AppThemeExtension appColors, required int? maxContext}) {
    final (measured, lastWindow, isEstimate, estimated, isBusy, hasMessages) = ref.watch(
      chatProvider.select((s) => (
            s.context.tokens,
            s.context.window,
            s.context.isEstimate,
            s.estimatedContextTokens,
            s.isGenerating || s.compactingStatus != null,
            s.messages.isNotEmpty,
          )),
    );
    final preferred = ref.watch(appSettingsProvider).contextWindow;

    int window = ContextManager.baselineWindow(maxContext: maxContext, preferredWindow: preferred);
    // On automatic the window grows with the prompt; show the one last used.
    if (preferred == null && lastWindow != null && lastWindow > window) {
      window = maxContext != null && maxContext > 0 && lastWindow > maxContext ? maxContext : lastWindow;
    }

    final used = measured ?? estimated;
    final isApproximate = measured == null || isEstimate;
    final left = used >= window ? 0 : window - used;
    final fraction = window <= 0 ? 0.0 : (used / window).clamp(0.0, 1.0);
    // Past three quarters the older turns are about to be folded into a summary.
    final isNearlyFull = fraction >= 0.75;
    final canCompact = hasMessages && !isBusy && widget.selectedModel != null;

    final usedLabel = '${isApproximate && used > 0 ? '~' : ''}${_compactTokens(used)}';
    final style = AppTypography.code.copyWith(
      fontSize: 10.5,
      color: appColors.textSecondary,
      fontWeight: FontWeight.w500,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(AppIcons.knowledge, size: 13.0, color: appColors.textSecondary),
            const SizedBox(width: 5.0),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: I18n.contextUsage(usedLabel, _windowSize(window), _compactTokens(left)),
                  children: [
                    if (maxContext != null && maxContext > 0)
                      TextSpan(
                        text: '  •  ${I18n.contextModelMax(_windowSize(maxContext))}',
                        style: TextStyle(color: appColors.textSecondary.withValues(alpha: 0.6)),
                      ),
                  ],
                ),
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12.0),
            Pressable(
              key: const Key('compact_button'),
              tooltip: I18n.compactTooltip,
              onTap: canCompact
                  ? () => ref.read(chatProvider.notifier).compactConversation(widget.selectedModel!)
                  : null,
              builder: (context, isHovered, _) => Text(
                I18n.compactAction,
                style: style.copyWith(
                  color: !canCompact
                      ? appColors.textSecondary.withValues(alpha: 0.4)
                      : (isHovered ? appColors.accent : appColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7.0),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: SizedBox(
            height: 3.0,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: appColors.border)),
                AnimatedFractionallySizedBox(
                  duration: AppMotion.slow,
                  curve: AppMotion.standard,
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  heightFactor: 1.0,
                  child: ColoredBox(color: isNearlyFull ? appColors.accent : appColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenStatsSection({
    required AppThemeExtension appColors,
    required TokenUsageStats tokenStats,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.speed, size: 13.0, color: appColors.textSecondary),
        const SizedBox(width: 5.0),
        Flexible(
          child: Text(
            '${tokenStats.todayFormatted} • ${tokenStats.totalFormatted}',
            style: AppTypography.code.copyWith(
              fontSize: 10.5,
              color: appColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _getModeLabel(ChatExecutionMode mode) {
    switch (mode) {
      case ChatExecutionMode.schnell:
        return I18n.isGerman ? 'Schnell' : 'Fast';
      case ChatExecutionMode.optimal:
        return I18n.isGerman ? 'Optimal' : 'Optimal';
      case ChatExecutionMode.thinking:
        return I18n.isGerman ? 'Denken' : 'Thinking';
    }
  }
}

/// The discrete toggle chevron button (`^`) positioned in the composer's header/top area.
class ShelfToggleButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const ShelfToggleButton({
    super.key,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Tooltip(
      message: isExpanded ? I18n.shelfCollapse : I18n.shelfExpand,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          hoverColor: appColors.hover,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: AppMotion.base,
              curve: Curves.easeInOutCubic,
              child: Icon(
                AppIcons.caretUp,
                size: 16.0,
                color: isExpanded ? appColors.accent : appColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
