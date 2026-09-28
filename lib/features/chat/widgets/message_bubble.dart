import 'package:flutter/material.dart';
import '../../../core/models/message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import 'claude_thinking_indicator.dart';
import 'think_block_view.dart';
import 'telemetry_footer.dart';
import 'markdown_view.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isThinking;
  final int branchIndex;
  final int totalBranches;
  final String modelName;
  final VoidCallback? onPreviousBranch;
  final VoidCallback? onNextBranch;
  final VoidCallback? onEdit;
  final VoidCallback? onRegenerate;
  
  const MessageBubble({
    super.key,
    required this.message,
    this.isThinking = false,
    this.branchIndex = 0,
    this.totalBranches = 1,
    this.modelName = 'qwen2.5:3b',
    this.onPreviousBranch,
    this.onNextBranch,
    this.onEdit,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.role == 'user';
    final appColors = context.appColors;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
          child: isUser ? _buildUserMessage(appColors) : _buildAssistantMessage(),
        ),
      ),
    );
  }

  Widget _buildUserMessage(AppThemeExtension appColors) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: appColors.surface,
            border: Border.all(color: appColors.borderSubtle),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: SelectableText(
            message.content,
            style: AppTypography.uiControl.copyWith(
              color: appColors.textPrimary,
              fontSize: 15.0,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Think Block
        if (message.thinkContent != null && message.thinkContent!.isNotEmpty)
          ThinkBlockView(
            thinkContent: message.thinkContent!,
            durationMs: message.generationDurationMs,
            tokens: message.tokens,
            isThinking: isThinking,
          ),
        
        // Claude-style playful thinking indicator when waiting for answer
        if (isThinking && message.content.isEmpty)
          const ClaudeThinkingIndicator(),

        // Main Answer Markdown
        if (message.content.isNotEmpty)
          MarkdownView(
            data: message.content,
          ),
        
        // Telemetry & Actions
        if (!isUser && !isThinking && message.content.isNotEmpty)
          TelemetryFooter(
            tokens: message.tokens,
            durationMs: message.generationDurationMs,
            modelName: modelName,
            contentToCopy: message.content,
            onRegenerate: onRegenerate,
          ),
      ],
    );
  }

  bool get isUser => message.role == 'user';
}
