import 'package:flutter/material.dart';
import '../../../core/constants/app_tokens.dart';
import 'package:flutter/rendering.dart';
import '../../../core/models/message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/tomsllama_logo.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/services/context_manager.dart';
import '../../../core/widgets/pressable.dart';
import 'claude_thinking_indicator.dart';
import 'message_bubble.dart';

class ChatViewport extends StatefulWidget {
  final List<Message> messages;
  final bool isGenerating;
  final String modelName;
  final String? statusMessage;
  final int? statusTokens;
  final int? statusEtaSeconds;
  final VoidCallback? onRegenerate;
  final String? errorMessage;
  final VoidCallback? onRetry;

  /// Summary standing in for the turns up to and including [summaryThroughId].
  final String? summary;
  final String? summaryThroughId;

  /// Progress line while the chat is being summarised on request.
  final String? compactingStatus;

  const ChatViewport({
    super.key,
    required this.messages,
    this.isGenerating = false,
    this.modelName = 'qwen2.5:3b',
    this.statusMessage,
    this.statusTokens,
    this.statusEtaSeconds,
    this.onRegenerate,
    this.errorMessage,
    this.onRetry,
    this.summary,
    this.summaryThroughId,
    this.compactingStatus,
  });

  @override
  State<ChatViewport> createState() => _ChatViewportState();
}

class _ChatViewportState extends State<ChatViewport> {
  final ScrollController _scrollController = ScrollController();
  bool _userScrolledUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      _userScrolledUp = true;
    } else if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      _userScrolledUp = false;
    }
  }

  @override
  void didUpdateWidget(ChatViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages != oldWidget.messages || (widget.isGenerating && !_userScrolledUp)) {
      // Glide for a new message, but only pin to the bottom while one is growing:
      // restarting a 250ms animation on every chunk never lets it finish.
      final isNewMessage = widget.messages.length != oldWidget.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom(animate: isNewMessage);
        }
      });
    }
  }

  void _scrollToBottom({required bool animate}) {
    if (!_scrollController.hasClients || _userScrolledUp) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: AppMotion.base,
        curve: AppMotion.standard,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    if (widget.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TomsllamaLogo(
              size: 53.0,
              animate: true,
              enableIdleAnimation: true,
            ),
            const SizedBox(height: 20.0),
            Text(
              'tomsllama',
              style: AppTypography.display.copyWith(color: appColors.textPrimary),
            ),
            const SizedBox(height: 6.0),
            Text(
              I18n.subtitle,
              style: AppTypography.body.copyWith(
                color: appColors.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
            if (widget.errorMessage != null) ...[
              const SizedBox(height: 18.0),
              _ErrorNotice(message: widget.errorMessage!, onRetry: widget.onRetry),
            ],
          ],
        ),
      );
    }

    final hasError = widget.errorMessage != null;
    final hasSummary = widget.summary != null && widget.summary!.trim().isNotEmpty;
    final dividerAfter = hasSummary ? widget.messages.indexWhere((m) => m.id == widget.summaryThroughId) : -1;

    // Rows in display order: messages, with the summary divider after the last
    // summarised one, then the summarising line and an error, if any.
    final rows = <Object>[];
    for (var i = 0; i < widget.messages.length; i++) {
      rows.add(widget.messages[i]);
      if (i == dividerAfter) rows.add(_Row.summaryDivider);
    }
    if (widget.compactingStatus != null) rows.add(_Row.compacting);
    if (hasError) rows.add(_Row.error);

    // One selection spans every message, so text can be copied across turns.
    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24.0, top: 20.0),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row == _Row.error) {
            return _column(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _ErrorNotice(message: widget.errorMessage!, onRetry: widget.onRetry),
              ),
            );
          }
          if (row == _Row.compacting) {
            return _column(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ClaudeThinkingIndicator(statusMessage: widget.compactingStatus),
              ),
            );
          }
          if (row == _Row.summaryDivider) {
            final before = widget.messages
                .take(dividerAfter + 1)
                .fold<int>(0, (sum, m) => sum + ContextManager.historyTokens(m));
            return _column(
              child: _SummaryDivider(
                summary: widget.summary!.trim(),
                tokensBefore: before,
                tokensAfter: ContextManager.estimateTokens(widget.summary!),
              ),
            );
          }

          final message = row as Message;
          final isLast = identical(message, widget.messages.last);

          return MessageBubble(
            message: message,
            isThinking: isLast && widget.isGenerating,
            statusMessage: isLast && widget.isGenerating ? widget.statusMessage : null,
            statusTokens: isLast && widget.isGenerating ? widget.statusTokens : null,
            statusEtaSeconds: isLast && widget.isGenerating ? widget.statusEtaSeconds : null,
            modelName: widget.modelName,
            branchIndex: 0,
            totalBranches: 1,
            onRegenerate: isLast ? widget.onRegenerate : null,
          );
        },
      ),
    );
  }

  // Same reading column as the message bubbles.
  Widget _column({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 24.0),
          child: child,
        ),
      ),
    );
  }
}

enum _Row { summaryDivider, compacting, error }

String _compactTokens(int tokens) => tokens >= 1000 ? '${(tokens / 1000).toStringAsFixed(1)}k' : '$tokens';

/// Marks where the summary takes over: everything above it is no longer sent
/// to the model. Opens to show what the model is told instead.
class _SummaryDivider extends StatefulWidget {
  final String summary;
  final int tokensBefore;
  final int tokensAfter;

  const _SummaryDivider({required this.summary, required this.tokensBefore, required this.tokensAfter});

  @override
  State<_SummaryDivider> createState() => _SummaryDividerState();
}

class _SummaryDividerState extends State<_SummaryDivider> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    Widget hairline() => Expanded(child: Container(height: 1.0, color: appColors.border));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          onTap: () => setState(() => _open = !_open),
          builder: (context, isHovered, _) {
            final color = isHovered ? appColors.textPrimary : appColors.textSecondary;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  hairline(),
                  const SizedBox(width: AppSpace.m),
                  Text(
                    // A summary of a very short chat saves nothing; then the numbers only confuse.
                    widget.tokensAfter < widget.tokensBefore
                        ? I18n.summarisedDivider(
                            _compactTokens(widget.tokensBefore),
                            _compactTokens(widget.tokensAfter),
                          )
                        : I18n.summarisedDividerPlain,
                    style: AppTypography.micro.copyWith(color: color),
                  ),
                  const SizedBox(width: 4.0),
                  Icon(_open ? AppIcons.caretUp : AppIcons.caretDown, size: 11.0, color: color),
                  const SizedBox(width: AppSpace.m),
                  hairline(),
                ],
              ),
            );
          },
        ),
        AnimatedSize(
          duration: AppMotion.slow,
          curve: AppMotion.standard,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 10.0),
                  child: Text(
                    widget.summary,
                    style: AppTypography.small.copyWith(color: appColors.textSecondary, height: 1.5),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Hairline notice for a failed request. Kept as quiet as the telemetry line:
/// an error here is usually "Ollama is not running", not something to shout about.
class _ErrorNotice extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorNotice({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
      decoration: BoxDecoration(
        color: appColors.background,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: appColors.border, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SelectableText(
              message,
              style: AppTypography.code.copyWith(
                color: appColors.textSecondary,
                fontSize: 12.0,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 12.0),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                child: Text(
                  I18n.retry,
                  style: AppTypography.label.copyWith(
                    color: appColors.accent,
                    fontSize: 12.0,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
