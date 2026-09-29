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
          child: isUser ? _buildUserMessage(context, appColors) : _buildAssistantMessage(),
        ),
      ),
    );
  }

  Widget _buildUserMessage(BuildContext context, AppThemeExtension appColors) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: appColors.surface,
            border: Border.all(color: appColors.borderSubtle),
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: isDark ? 16.0 : 12.0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.20)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 4.0,
                offset: const Offset(0, 1),
              ),
            ],
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
                        padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: appColors.hover,
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(color: appColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_outlined, size: 12.0, color: appColors.accent),
                            const SizedBox(width: 4.0),
                            Text(
                              workspaceName,
                              style: AppTypography.code.copyWith(
                                fontSize: 11.0,
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
                        padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: appColors.hover,
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(color: appColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              file.toLowerCase().endsWith('.pdf')
                                  ? Icons.picture_as_pdf_outlined
                                  : Icons.insert_drive_file_outlined,
                              size: 12.0,
                              color: file.toLowerCase().endsWith('.pdf')
                                  ? Colors.redAccent.shade200
                                  : appColors.accent,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              file,
                              style: AppTypography.code.copyWith(
                                fontSize: 11.0,
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
                SelectableText(
                  displayText,
                  style: AppTypography.uiControl.copyWith(
                    color: appColors.textPrimary,
                    fontSize: 15.0,
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
