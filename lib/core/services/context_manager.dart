import '../models/message.dart';

class ContextBudget {
  /// `num_ctx` to send to Ollama, or null to leave the model's default untouched.
  final int? numCtx;

  /// Token budget for [ContextManager.applySlidingWindow].
  final int historyTokens;

  /// Size of the context window the turn runs in.
  final int window;

  const ContextBudget({required this.numCtx, required this.historyTokens, required this.window});
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
  /// The lowest tier sends no `num_ctx` and budgets for the daemon's default:
  /// [defaultWindow] once it has been observed, a cautious 2048 before that.
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
    int? maxContext,
    int? preferredWindow,
    int? defaultWindow,
  }) {
    final base = defaultWindow != null && defaultWindow > 0 ? defaultWindow : 2048;
    final fixedTokens = systemTokens + promptTokens;
    final hasModelLimit = maxContext != null && maxContext > 0;

    int? numCtx;
    int window;
    final int replyReserve;
    if (preferredWindow != null && (preferredWindow > 0 || hasModelLimit)) {
      // The user chose a window: one size for every turn, so the runner never reloads.
      window = preferredWindow > 0 ? preferredWindow : maxContext!;
      numCtx = window;
      replyReserve = (window ~/ 8).clamp(400, 2000);
    } else if (fixedTokens > 3600 && base < 8192) {
      numCtx = 8192;
      window = 8192;
      replyReserve = 600;
    } else if (fixedTokens > 1800 && base < 4096) {
      numCtx = 4096;
      window = 4096;
      replyReserve = 500;
    } else {
      numCtx = null;
      window = base;
      replyReserve = base >= 8192 ? 600 : (base >= 4096 ? 500 : 400);
    }

    // Never ask for more context than the model was trained for.
    if (hasModelLimit && window > maxContext) {
      window = maxContext;
      if (numCtx != null) numCtx = maxContext;
    }

    final hiddenPromptTokens = promptTokens > latestMessageTokens ? promptTokens - latestMessageTokens : 0;
    final historyTokens = window - replyReserve - systemTokens - hiddenPromptTokens;

    return ContextBudget(
      numCtx: numCtx,
      historyTokens: historyTokens > 0 ? historyTokens : 0,
      window: window,
    );
  }

  /// The window a chat on a model with [maxContext] runs in before any turn
  /// has reported one: the user's choice, or the smallest automatic tier.
  static int baselineWindow({int? maxContext, int? preferredWindow, int? defaultWindow}) {
    return planBudget(
      systemTokens: 0,
      promptTokens: 0,
      latestMessageTokens: 0,
      maxContext: maxContext,
      preferredWindow: preferredWindow,
      defaultWindow: defaultWindow,
    ).window;
  }

  /// Tokens a stored message costs when it is sent back as history.
  ///
  /// Only `content` is resent. For a message with a think block the stored
  /// token count includes the reasoning, which would charge the history budget
  /// for text that never goes back to the model, so the content is re-estimated.
  static int historyTokens(Message msg) {
    if (msg.thinkContent != null || msg.tokens <= 0) return estimateTokens(msg.content);
    return msg.tokens;
  }

  /// Decides how many leading turns of [history] to fold into a summary.
  ///
  /// Returns 0 while the history is below three quarters of [budgetTokens].
  /// Past that it keeps the newest turns up to half the budget and returns the
  /// number of older messages to summarise. Cutting in one larger step, rather
  /// than sliding a little every turn, keeps the prompt prefix stable between
  /// compactions so Ollama's prompt cache keeps hitting.
  static int planCompaction({required List<Message> history, required int budgetTokens}) {
    if (history.length <= 2 || budgetTokens <= 0) return 0;

    final total = history.fold<int>(0, (sum, m) => sum + historyTokens(m));
    if (total <= budgetTokens * 3 ~/ 4) return 0;

    // Always keep the exchange that just finished.
    int cut = history.length - 2;
    int kept = historyTokens(history[cut]) + historyTokens(history[cut + 1]);
    while (cut > 0 && kept + historyTokens(history[cut - 1]) <= budgetTokens ~/ 2) {
      cut--;
      kept += historyTokens(history[cut]);
    }

    // The kept part must start with a user turn, or the model sees an answer without its question.
    while (cut < history.length && history[cut].role != 'user') {
      cut++;
    }
    return cut >= history.length ? 0 : cut;
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
      final msgTokens = historyTokens(msg);

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
