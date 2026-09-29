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
  final VoidCallback? onRegenerate;

  const ChatViewport({
    super.key,
    required this.messages,
    this.isGenerating = false,
    this.modelName = 'qwen2.5:3b',
    this.onRegenerate,
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
              size: 46.0,
              animate: true,
              enableIdleAnimation: true,
            ),
            const SizedBox(height: 20.0),
            Text(
              'tomsllama',
              style: AppTypography.headline.copyWith(
                color: appColors.textPrimary,
                fontSize: 26.4,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              I18n.subtitle,
              style: AppTypography.uiControl.copyWith(
                color: appColors.textSecondary,
                fontSize: 15.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 24.0, top: 20.0),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        final isLast = index == widget.messages.length - 1;
        
        return MessageBubble(
          message: message,
          isThinking: isLast && widget.isGenerating,
          modelName: widget.modelName,
          branchIndex: 0,
          totalBranches: 1,
          onRegenerate: isLast ? widget.onRegenerate : null,
        );
      },
    );
  }
}
