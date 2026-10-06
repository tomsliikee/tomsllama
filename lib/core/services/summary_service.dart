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
  static const int maxSummaryChars = 1500;

  static String _line(Message turn, int maxCharsPerTurn) {
    final speaker = turn.role == 'user' ? 'User' : 'Assistant';
    final text = turn.content.trim();
    final clipped = text.length > maxCharsPerTurn ? '${text.substring(0, maxCharsPerTurn)} [...]' : text;
    return '$speaker: $clipped\n';
  }

  static String buildPrompt({
    String? previousSummary,
    required List<Message> turns,
    String? instructions,
    int maxCharsPerTurn = _maxCharsPerTurn,
    int maxTranscriptChars = _maxTranscriptChars,
  }) {
    final transcript = StringBuffer();
    for (final turn in turns) {
      final line = _line(turn, maxCharsPerTurn);
      if (transcript.length + line.length > maxTranscriptChars) break;
      transcript.write(line);
    }

    // Small models drop what the user said about themselves first and follow
    // the last line of a prompt best, so both are spelled out, the request last.
    final buffer = StringBuffer()
      ..writeln('Summarize the conversation below so that the summary can replace it.')
      ..writeln('Write at most 150 words, in the language of the conversation, with no preamble.')
      ..writeln('Keep, most important first:')
      ..writeln('1. Everything the user said about themselves, their things and their goals: names, numbers, preferences.')
      ..writeln('2. Decisions, facts and code identifiers.')
      ..writeln('3. Questions that are still open.');
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
    if (instructions != null && instructions.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('The summary must also do this: ${instructions.trim()}');
    }
    return buffer.toString().trim();
  }

  /// Splits [turns] into runs whose transcript fits [maxTranscriptChars] each,
  /// so a long chat is summarised piece by piece instead of being cut off.
  static List<List<Message>> chunkTurns(
    List<Message> turns, {
    required int maxCharsPerTurn,
    required int maxTranscriptChars,
  }) {
    final chunks = <List<Message>>[];
    var current = <Message>[];
    var length = 0;
    for (final turn in turns) {
      final lineLength = _line(turn, maxCharsPerTurn).length;
      if (current.isNotEmpty && length + lineLength > maxTranscriptChars) {
        chunks.add(current);
        current = <Message>[];
        length = 0;
      }
      current.add(turn);
      length += lineLength;
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  /// Summarises every turn in [turns], however long, by rolling the summary
  /// through as many requests as the transcript needs to fit [window] tokens.
  ///
  /// Returns null if any step fails: a summary that silently skipped part of
  /// the chat would be worse than keeping the turns.
  static Future<String?> summarizeAll({
    required String model,
    String? previousSummary,
    required List<Message> turns,
    required int window,
    String? instructions,
    int? numCtx,
    bool? think,
    void Function(int step, int steps)? onProgress,
  }) async {
    if (turns.isEmpty) return null;

    // Leave room for the instructions, the running summary and the reply.
    final transcriptChars = ((window - 900) * 3).clamp(_maxTranscriptChars, 60000);
    final perTurnChars = (transcriptChars ~/ 3).clamp(_maxCharsPerTurn, 4000);
    final chunks = chunkTurns(turns, maxCharsPerTurn: perTurnChars, maxTranscriptChars: transcriptChars);

    String? summary = previousSummary;
    for (var i = 0; i < chunks.length; i++) {
      onProgress?.call(i + 1, chunks.length);
      summary = await summarize(
        model: model,
        previousSummary: summary,
        turns: chunks[i],
        instructions: instructions,
        maxCharsPerTurn: perTurnChars,
        maxTranscriptChars: transcriptChars,
        numCtx: numCtx,
        think: think,
      );
      if (summary == null) return null;
    }
    return summary;
  }

  /// Returns the new summary, or null if the model could not produce one.
  static Future<String?> summarize({
    required String model,
    String? previousSummary,
    required List<Message> turns,
    String? instructions,
    int maxCharsPerTurn = _maxCharsPerTurn,
    int maxTranscriptChars = _maxTranscriptChars,
    int? numCtx,
    bool? think,
  }) async {
    if (turns.isEmpty) return null;

    final reply = await OllamaService().chatTurn(
      model,
      [
        {
          'role': 'user',
          'content': buildPrompt(
            previousSummary: previousSummary,
            turns: turns,
            instructions: instructions,
            maxCharsPerTurn: maxCharsPerTurn,
            maxTranscriptChars: maxTranscriptChars,
          ),
        },
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
