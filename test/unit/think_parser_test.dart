import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/utils/think_parser.dart';

void main() {
  test('Think parser handles normal text', () {
    final result = ThinkParser.parse('Hello world');
    expect(result.content, 'Hello world');
    expect(result.thinkContent, '');
    expect(result.isThinking, false);
  });

  test('Think parser handles ongoing thought', () {
    final result = ThinkParser.parse('<think>Thinking about it...');
    expect(result.content, '');
    expect(result.thinkContent, 'Thinking about it...');
    expect(result.isThinking, true);
  });

  test('Think parser handles closed thought', () {
    final result = ThinkParser.parse('<think>Done thinking</think>Here is the answer.');
    expect(result.content, 'Here is the answer.');
    expect(result.thinkContent, 'Done thinking');
    expect(result.isThinking, false);
  });
}
