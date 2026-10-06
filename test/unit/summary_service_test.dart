import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/models/message.dart';
import 'package:tomsllama/core/services/summary_service.dart';

Message _turn(int i, String content) => Message(
      id: 'm$i',
      conversationId: 'c',
      role: i.isEven ? 'user' : 'assistant',
      content: content,
      createdAt: DateTime(2026),
    );

void main() {
  test('a long chat is split into chunks that together hold every turn', () {
    final turns = [for (var i = 0; i < 10; i++) _turn(i, 'x' * 900)];

    final chunks = SummaryService.chunkTurns(turns, maxCharsPerTurn: 1000, maxTranscriptChars: 3000);

    expect(chunks.length, greaterThan(1));
    expect(chunks.expand((c) => c).map((m) => m.id), turns.map((m) => m.id));
    for (final chunk in chunks) {
      final prompt = SummaryService.buildPrompt(turns: chunk, maxCharsPerTurn: 1000, maxTranscriptChars: 3000);
      for (final turn in chunk) {
        expect(prompt, contains(turn.role == 'user' ? 'User: ' : 'Assistant: '));
      }
      expect(RegExp('x{900}').allMatches(prompt), hasLength(chunk.length));
    }
  });

  test('a turn longer than a whole chunk still gets one of its own', () {
    final chunks = SummaryService.chunkTurns(
      [_turn(0, 'a' * 5000), _turn(1, 'short')],
      maxCharsPerTurn: 4000,
      maxTranscriptChars: 3000,
    );
    expect(chunks.map((c) => c.length), [1, 1]);
  });

  test('instructions given with the command reach the prompt', () {
    final prompt = SummaryService.buildPrompt(turns: [_turn(0, 'hello')], instructions: 'keep the SQL schema');
    expect(prompt, contains('keep the SQL schema'));
  });
}
