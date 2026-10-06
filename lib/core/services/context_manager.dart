import '../models/message.dart';

class ContextBudget {
  /// `num_ctx` to send to Ollama, or null to leave the model's default untouched.
  final int? numCtx;

  /// Token budget for [ContextManager.applySlidingWindow].
  final int historyTokens;

  const ContextBudget({required this.numCtx, required this.historyTokens});
}

class ContextManager {
  /// Default sliding window limit suited for Intel i5-8350U (CPU inference)
  static const int defaultTokenLimit = 4096;

  /// A heuristic for token counting calibrated for local models (e.g. Qwen2.5/Llama3).
  /// Empirically, German text, code syntax, umlauts, and markdown formatting
  /// average ~2.8 to 3.2 characters per token. We use a conservative 3 chars/token
  /// to avoid underestimating context size and memory latency.
  static int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    return (text.length / 3).ceil();
  }

  /// Picks the `num_ctx` tier for a turn and the token budget left for chat history.
  ///
  /// Tiers are discrete so Ollama does not reload the runner on every small change.
  /// The lowest tier sends no `num_ctx` and budgets for Ollama's 2048 default.
  ///
  /// The history budget is what remains after the system prompt, the part of the
  /// current prompt that [applySlidingWindow] cannot see (attached file bodies are
  /// in the payload, not in the stored message), and a reserve for the reply.
  /// Without subtracting those, system prompt plus history can exceed `num_ctx`
  /// and Ollama silently cuts the front of the prompt, where workspace files sit.
  static ContextBudget planBudget({
    required int systemTokens,
    required int promptTokens,
    required int latestMessageTokens,
  }) {
    final fixedTokens = systemTokens + promptTokens;

    final int? numCtx;
    final int window;
    final int replyReserve;
    if (fixedTokens > 3600) {
      numCtx = 8192;
      window = 8192;
      replyReserve = 600;
    } else if (fixedTokens > 1800) {
      numCtx = 4096;
      window = 4096;
      replyReserve = 500;
    } else {
      numCtx = null;
      window = 2048;
      replyReserve = 400;
    }

    final hiddenPromptTokens = promptTokens > latestMessageTokens ? promptTokens - latestMessageTokens : 0;
    final historyTokens = window - replyReserve - systemTokens - hiddenPromptTokens;

    return ContextBudget(
      numCtx: numCtx,
      historyTokens: historyTokens > 0 ? historyTokens : 0,
    );
  }

  /// Trims the message history to fit within the [maxTokens] limit.
  /// 
  /// Rules:
  /// 1. The system prompt (if present) is ALWAYS kept.
  /// 2. The most recent messages are prioritized.
  /// 3. Older messages are dropped if the token budget is exceeded.
  static List<Message> applySlidingWindow({
    required List<Message> messages,
    int maxTokens = defaultTokenLimit,
  }) {
    if (messages.isEmpty) return [];

    final List<Message> keptMessages = [];
    int currentTokens = 0;

    // 1. Identify and keep system prompts first
    for (final msg in messages) {
      if (msg.role == 'system') {
        keptMessages.add(msg);
        currentTokens += msg.tokens > 0 ? msg.tokens : estimateTokens(msg.content);
      }
    }

    // 2. Process remaining messages from newest to oldest
    final nonSystemMessages = messages.where((m) => m.role != 'system').toList();
    final List<Message> recentHistory = [];

    for (int i = nonSystemMessages.length - 1; i >= 0; i--) {
      final msg = nonSystemMessages[i];
      // Estimate tokens including thinkContent if it exists
      final contentTokens = msg.tokens > 0 ? msg.tokens : estimateTokens(msg.content);
      final thinkTokens = msg.thinkContent != null ? estimateTokens(msg.thinkContent!) : 0;
      final msgTokens = contentTokens + thinkTokens;

      // The latest user message must NEVER be dropped
      final isLatestMessage = (i == nonSystemMessages.length - 1);

      if (isLatestMessage || (currentTokens + msgTokens <= maxTokens)) {
        recentHistory.insert(0, msg);
        currentTokens += msgTokens;
      } else {
        // Budget exceeded, we stop including older messages.
        break;
      }
    }

    keptMessages.addAll(recentHistory);
    return keptMessages;
  }
}
