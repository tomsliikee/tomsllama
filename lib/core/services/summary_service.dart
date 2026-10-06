import '../models/message.dart';
import '../utils/think_parser.dart';
import 'ollama_service.dart';

/// Condenses turns that are about to leave the context window into a short
/// running summary, so a small-context model keeps the thread of a long chat.
class SummaryService {
  // The transcript has to fit the same context window as the chat itself:
  // asking for a larger num_ctx here would make Ollama reload the model.
  static const int _maxCharsPerTurn = 500;
  static const int _maxTranscriptChars = 3500;
  static const int maxSummaryChars = 1200;

  static String buildPrompt({String? previousSummary, required List<Message> turns}) {
    final transcript = StringBuffer();
    for (final turn in turns) {
      final speaker = turn.role == 'user' ? 'User' : 'Assistant';
      final text = turn.content.trim();
      final clipped = text.length > _maxCharsPerTurn ? '${text.substring(0, _maxCharsPerTurn)} [...]' : text;
      final line = '$speaker: $clipped\n';
      if (transcript.length + line.length > _maxTranscriptChars) break;
      transcript.write(line);
    }

    final buffer = StringBuffer()
      ..writeln('Summarize the conversation below in at most 120 words, in the language it is written in.')
      ..writeln('Keep names, decisions, facts, numbers, code identifiers and open questions. No preamble.');
    if (previousSummary != null && previousSummary.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Summary so far:')
        ..writeln(previousSummary.trim());
    }
    buffer
      ..writeln()
      ..writeln('New turns:')
      ..write(transcript);
    return buffer.toString().trim();
  }

  /// Returns the new summary, or null if the model could not produce one.
  static Future<String?> summarize({
    required String model,
    String? previousSummary,
    required List<Message> turns,
    int? numCtx,
    bool? think,
  }) async {
    if (turns.isEmpty) return null;

    final reply = await OllamaService().chatTurn(
      model,
      [
        {'role': 'user', 'content': buildPrompt(previousSummary: previousSummary, turns: turns)},
      ],
      temperature: 0.2,
      numCtx: numCtx,
      think: think,
    );
    final raw = reply?['content'];
    if (raw is! String) return null;

    final text = ThinkParser.parse(raw).content.trim();
    if (text.isEmpty) return null;
    return text.length > maxSummaryChars ? text.substring(0, maxSummaryChars) : text;
  }
}
