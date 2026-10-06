import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/models/message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../shell/widgets/tomsllama_logo.dart';
import '../../../core/services/localization_service.dart';
import 'message_bubble.dart';

class ChatViewport extends StatefulWidget {
  final List<Message> messages;
  final bool isGenerating;
  final String modelName;
  final String? statusMessage;
  final int? statusTokens;
  final VoidCallback? onRegenerate;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const ChatViewport({
    super.key,
    required this.messages,
    this.isGenerating = false,
    this.modelName = 'qwen2.5:3b',
    this.statusMessage,
    this.statusTokens,
    this.onRegenerate,
    this.errorMessage,
    this.onRetry,
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && !_userScrolledUp) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
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
            const SizedBox(height: 22.0),
            Text(
              'tomsllama',
              style: AppTypography.headline.copyWith(
                color: appColors.textPrimary,
                fontSize: 30.0,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              I18n.subtitle,
              style: AppTypography.uiControl.copyWith(
                color: appColors.textSecondary,
                fontSize: 17.0,
                fontWeight: FontWeight.w400,
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 24.0, top: 20.0),
      itemCount: widget.messages.length + (hasError ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.messages.length) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 24.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ErrorNotice(message: widget.errorMessage!, onRetry: widget.onRetry),
                ),
              ),
            ),
          );
        }
        final message = widget.messages[index];
        final isLast = index == widget.messages.length - 1;
        
        return MessageBubble(
          message: message,
          isThinking: isLast && widget.isGenerating,
          statusMessage: isLast && widget.isGenerating ? widget.statusMessage : null,
          statusTokens: isLast && widget.isGenerating ? widget.statusTokens : null,
          modelName: widget.modelName,
          branchIndex: 0,
          totalBranches: 1,
          onRegenerate: isLast ? widget.onRegenerate : null,
        );
      },
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
        borderRadius: BorderRadius.circular(12.0),
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
                fontSize: 11.5,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 12.0),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(6.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                child: Text(
                  I18n.retry,
                  style: AppTypography.uiControl.copyWith(
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
