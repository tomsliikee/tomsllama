import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tomsllama/core/models/conversation.dart';
import 'package:tomsllama/core/models/message.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Database schema and CRUD operations for conversations and messages', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE conversations (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              total_tokens INTEGER DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE messages (
              id TEXT PRIMARY KEY,
              conversation_id TEXT NOT NULL,
              parent_id TEXT,
              role TEXT NOT NULL,
              content TEXT NOT NULL,
              think_content TEXT,
              created_at TEXT NOT NULL,
              tokens INTEGER DEFAULT 0,
              generation_duration_ms INTEGER DEFAULT 0,
              FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
            )
          ''');
        },
      ),
    );

    final now = DateTime.now();
    final conv = Conversation(
      id: 'test_conv_1',
      title: 'Architektur Diskussion',
      createdAt: now,
      updatedAt: now,
      totalTokens: 42,
    );

    // Insert conversation
    await db.insert('conversations', conv.toMap());
    final convResults = await db.query('conversations');
    expect(convResults.length, 1);
    expect(convResults.first['title'], 'Architektur Diskussion');

    // Insert Message
    final msg = Message(
      id: 'msg_1',
      conversationId: 'test_conv_1',
      role: 'user',
      content: 'Wie baue ich ein sauberes System?',
      createdAt: now,
    );
    await db.insert('messages', msg.toMap());
    final msgResults = await db.query('messages', where: 'conversation_id = ?', whereArgs: ['test_conv_1']);
    expect(msgResults.length, 1);
    expect(msgResults.first['content'], 'Wie baue ich ein sauberes System?');

    // Delete conversation
    await db.delete('conversations', where: 'id = ?', whereArgs: ['test_conv_1']);
    final emptyResults = await db.query('conversations');
    expect(emptyResults.isEmpty, true);

    await db.close();
  });
}
