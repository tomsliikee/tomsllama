import 'package:flutter/material.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/models/message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/widgets/ink_fade_in.dart';
import '../../../core/widgets/tomsllama_logo.dart';
import 'claude_thinking_indicator.dart';
import 'think_block_view.dart';
import 'telemetry_footer.dart';
import 'markdown_view.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isThinking;
  final String? statusMessage;
  final int? statusTokens;
  final int? statusEtaSeconds;
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
    this.statusMessage,
    this.statusTokens,
    this.statusEtaSeconds,
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
          // Only a message that was just written settles in; scrolling an old one
          // back into view must not replay the entrance.
          child: InkFadeIn(
            enabled: DateTime.now().difference(message.createdAt) < const Duration(seconds: 3),
            // Full column width, so a short line (the waiting indicator, a one-word
            // answer) starts at the left edge instead of being centred.
            child: SizedBox(
              width: double.infinity,
              child: isUser ? _buildUserMessage(context, appColors) : _buildAssistantMessage(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserMessage(BuildContext context, AppThemeExtension appColors) {
        // Parse clean display text and any attached files / workspace
    String displayText = message.content;
    final List<String> attachedFiles = [];
    String? workspaceName;
    String? gitBranch;

    if (displayText.contains('#### User Request:')) {
      final parts = displayText.split(RegExp(r'#### User Request:\s*'));
      displayText = parts.last.trim();
      final header = parts.first;

      // Extract workspace if present
      final wsMatch = RegExp(r'### Project Workspace: `([^`]+)`(?:\s*\(Git Branch: `([^`]+)`\))?').firstMatch(header);
      if (wsMatch != null) {
        workspaceName = wsMatch.group(1);
        gitBranch = wsMatch.group(2);
      }

      // Extract attached files if present
      final fileMatches = RegExp(r'`([^`\n]+)`\n```').allMatches(header);
      for (final m in fileMatches) {
        attachedFiles.add(m.group(1)!);
      }
    } else if (displayText.startsWith('[attached:')) {
      final endIdx = displayText.indexOf(']');
      if (endIdx != -1) {
        final meta = displayText.substring(10, endIdx);
        attachedFiles.addAll(meta.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
        displayText = displayText.substring(endIdx + 1).trim();
      }
    }

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          // Set apart by a warm fill rather than a shadow: it sits on the page, it does not float.
          decoration: BoxDecoration(
            color: appColors.sidebar,
            border: Border.all(color: appColors.borderSubtle),
            borderRadius: BorderRadius.circular(AppRadii.panel),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (workspaceName != null || attachedFiles.isNotEmpty) ...[
                Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: [
                    if (workspaceName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: appColors.background,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: appColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(AppIcons.folder, size: 12.0, color: appColors.accent),
                            const SizedBox(width: 4.0),
                            Text(
                              workspaceName,
                              style: AppTypography.code.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: appColors.textPrimary,
                              ),
                            ),
                            if (gitBranch != null) ...[
                              const SizedBox(width: 4.0),
                              Text('($gitBranch)', style: AppTypography.code.copyWith(fontSize: 10.5, color: appColors.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                    for (final file in attachedFiles)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: appColors.background,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: appColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              file.toLowerCase().endsWith('.pdf')
                                  ? AppIcons.pdf
                                  : AppIcons.file,
                              size: 12.0,
                              color: file.toLowerCase().endsWith('.pdf')
                                  ? appColors.accent
                                  : appColors.accent,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              file,
                              style: AppTypography.code.copyWith(
                                fontSize: 10.5,
                                color: appColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (displayText.isNotEmpty) const SizedBox(height: 8.0),
              ],
              if (displayText.isNotEmpty)
                Text(
                  displayText,
                  style: AppTypography.body.copyWith(
                    color: appColors.textPrimary,
                    height: 1.5,
                  ),
                ),
            ],
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
        
        // Claude-style unified thinking & status indicator when waiting for answer
        if (isThinking && message.content.isEmpty && (message.thinkContent == null || message.thinkContent!.isEmpty))
          ClaudeThinkingIndicator(
            statusMessage: statusMessage,
            totalTokens: statusTokens,
            etaSeconds: statusEtaSeconds,
          ),

        // Main Answer Markdown
        if (message.content.isNotEmpty)
          MarkdownView(
            data: message.content,
          ),
        
        // While the answer is still being written, a breathing mark holds the place of the next word
        if (isThinking && message.content.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10.0),
            child: TomsllamaLogo(size: 14.0, breathing: true),
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
