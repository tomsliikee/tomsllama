class ThinkParser {
  /// Parses the raw stream text into think content and actual content.
  /// Handles the case where </think> hasn't arrived yet.
  static ParsedThinkResult parse(String rawText) {
    String content = '';
    String thinkContent = '';
    bool isThinking = false;

    // We can use a simple state-based parsing or regex.
    // Given <think> and </think> are the exact tags Ollama models emit:
    
    final thinkStart = rawText.indexOf('<think>');
    if (thinkStart == -1) {
      // No think tag found
      return ParsedThinkResult(
        content: rawText,
        thinkContent: '',
        isThinking: false,
      );
    }

    final thinkEnd = rawText.indexOf('</think>', thinkStart);
    
    if (thinkEnd == -1) {
      // Currently thinking, no closing tag yet.
      // Content before <think>
      content = rawText.substring(0, thinkStart);
      // Content inside <think>
      thinkContent = rawText.substring(thinkStart + 7);
      isThinking = true;
    } else {
      // Think tag is closed.
      content = rawText.substring(0, thinkStart) + rawText.substring(thinkEnd + 8);
      thinkContent = rawText.substring(thinkStart + 7, thinkEnd);
      isThinking = false;
    }

    return ParsedThinkResult(
      content: content.trimLeft(),
      thinkContent: thinkContent.trimLeft(),
      isThinking: isThinking,
    );
  }
}

class ParsedThinkResult {
  final String content;
  final String thinkContent;
  final bool isThinking;

  const ParsedThinkResult({
    required this.content,
    required this.thinkContent,
    required this.isThinking,
  });
}
