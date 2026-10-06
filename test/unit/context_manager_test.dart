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

  group('planBudget', () {
    test('small turns keep the model default and leave room for history', () {
      final budget = ContextManager.planBudget(systemTokens: 100, promptTokens: 50, latestMessageTokens: 50);
      expect(budget.numCtx, isNull);
      expect(budget.historyTokens, 2048 - 400 - 100);
    });

    test('system prompt and attached file bodies are taken out of the history budget', () {
      // 800 system + 500 prompt, of which only 20 are visible to the sliding window.
      final budget = ContextManager.planBudget(systemTokens: 800, promptTokens: 500, latestMessageTokens: 20);
      expect(budget.numCtx, isNull);
      expect(budget.historyTokens, 2048 - 400 - 800 - 480);
      expect(800 + 500 + (budget.historyTokens - 20), lessThanOrEqualTo(2048 - 400));
    });

    test('larger turns move up a tier and never return a negative budget', () {
      final mid = ContextManager.planBudget(systemTokens: 1500, promptTokens: 600, latestMessageTokens: 600);
      expect(mid.numCtx, 4096);
      expect(mid.historyTokens, 4096 - 500 - 1500);

      final large = ContextManager.planBudget(systemTokens: 3000, promptTokens: 1000, latestMessageTokens: 30);
      expect(large.numCtx, 8192);

      final overfull = ContextManager.planBudget(systemTokens: 9000, promptTokens: 2000, latestMessageTokens: 10);
      expect(overfull.numCtx, 8192);
      expect(overfull.historyTokens, 0);
    });
  });

  group('planCompaction', () {
    List<Message> turns(int count, int tokensEach) => [
          for (var i = 0; i < count; i++)
            createMessage('m$i', i.isEven ? 'user' : 'assistant', 'text', tokens: tokensEach),
        ];

    test('leaves history alone below three quarters of the budget', () {
      expect(ContextManager.planCompaction(history: turns(6, 100), budgetTokens: 1000), 0);
    });

    test('keeps the newest turns up to half the budget and starts on a user turn', () {
      final history = turns(10, 100); // 1000 tokens against a budget of 1000
      final cut = ContextManager.planCompaction(history: history, budgetTokens: 1000);
      expect(cut, 6);
      expect(history[cut].role, 'user');
    });

    test('always keeps the exchange that just finished, however large', () {
      final history = turns(4, 900);
      expect(ContextManager.planCompaction(history: history, budgetTokens: 1000), 2);
    });

    test('a think block is not charged to the history budget', () {
      final withThink = Message(
        id: 't',
        conversationId: 'c1',
        role: 'assistant',
        content: 'short',
        thinkContent: 'long reasoning ' * 200,
        tokens: 1200,
        createdAt: DateTime.now(),
      );
      expect(ContextManager.historyTokens(withThink), ContextManager.estimateTokens('short'));
    });
  });
}
