import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/models/message.dart';
import 'package:tomsllama/core/services/context_manager.dart';

void main() {
  Message createMessage(String id, String role, String content, {int tokens = 0}) {
    return Message(
      id: id,
      conversationId: 'c1',
      role: role,
      content: content,
      tokens: tokens,
      createdAt: DateTime.now(),
    );
  }

  test('Context manager keeps system prompt and fits latest messages', () {
    final messages = [
      createMessage('1', 'system', 'You are a helpful assistant.', tokens: 10),
      createMessage('2', 'user', 'Hello!', tokens: 1000),
      createMessage('3', 'assistant', 'Hi there.', tokens: 1000),
      createMessage('4', 'user', 'What is 1+1?', tokens: 1000),
      createMessage('5', 'assistant', 'It is 2.', tokens: 1000),
      createMessage('6', 'user', 'And 2+2?', tokens: 1000), // Should fit
    ];

    // Total tokens: 10 + 5000 = 5010 > 4096. 
    // It should keep system (10), and the most recent 4086 tokens.
    // 4 messages of 1000 tokens fit. So it keeps system, and messages 3, 4, 5, 6.

    final trimmed = ContextManager.applySlidingWindow(
      messages: messages,
      maxTokens: 4096,
    );

    expect(trimmed.length, 5); // System + 4 latest
    expect(trimmed[0].id, '1'); // System kept
    expect(trimmed[1].id, '3');
    expect(trimmed[2].id, '4');
    expect(trimmed[3].id, '5');
    expect(trimmed[4].id, '6');
  });

  test('Context manager estimates tokens correctly', () {
    expect(ContextManager.estimateTokens('123'), 1);
    expect(ContextManager.estimateTokens('123456'), 2);
    expect(ContextManager.estimateTokens('1234'), 2);
  });
}
