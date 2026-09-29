import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/persona.dart';
import '../models/workspace.dart';
import '../models/workspace_context_file.dart';
import '../models/token_usage_stats.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final oldDbPath = join(appDocDir.path, 'gemlama', 'gemlama.db');
    final dbPath = join(appDocDir.path, 'tomsllama', 'tomsllama.db');
    
    // Ensure directory exists
    await Directory(dirname(dbPath)).create(recursive: true);

    // Seamless migration from gemlama if exists
    final oldFile = File(oldDbPath);
    final newFile = File(dbPath);
    if (await oldFile.exists() && !await newFile.exists()) {
      try {
        await oldFile.copy(dbPath);
      } catch (_) {}
    }

    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
        onOpen: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
          try {
            await db.execute('ALTER TABLE conversations ADD COLUMN is_pinned INTEGER DEFAULT 0;');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE conversations ADD COLUMN sort_order INTEGER DEFAULT 0;');
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE conversations ADD COLUMN persona TEXT DEFAULT 'Standard';");
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE conversations ADD COLUMN workspace_id TEXT;');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE conversations ADD COLUMN is_workspace_context_enabled INTEGER DEFAULT 1;');
          } catch (_) {}
          await db.execute('''
            CREATE TABLE IF NOT EXISTS workspaces (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              prompt TEXT DEFAULT '',
              is_pinned INTEGER DEFAULT 0,
              sort_order INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS workspace_context_files (
              id TEXT PRIMARY KEY,
              workspace_id TEXT NOT NULL,
              file_path TEXT NOT NULL,
              file_name TEXT NOT NULL,
              file_size INTEGER NOT NULL,
              content TEXT,
              estimated_tokens INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
            );
          ''');
        },
      ),
    );

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workspaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        prompt TEXT DEFAULT '',
        is_pinned INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workspace_context_files (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        content TEXT,
        estimated_tokens INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        total_tokens INTEGER DEFAULT 0,
        is_pinned INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        persona TEXT DEFAULT 'Standard',
        workspace_id TEXT,
        is_workspace_context_enabled INTEGER DEFAULT 1,
        FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
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

    await db.execute('''
      CREATE TABLE personas (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        system_prompt TEXT NOT NULL
      )
    ''');
    
    // Add default Standard persona
    await db.insert('personas', {
      'id': 'default-standard',
      'name': 'Standard',
      'system_prompt': 'You are a calm, highly capable AI assistant. Answer directly, concisely and accurately without fluff, conversational filler, or unnecessary apologies.'
    });
  }

  // --- Conversations ---
  
  Future<void> updateConversationPersona(String id, String persona) async {
    final db = await database;
    await db.update(
      'conversations',
      {'persona': persona},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> saveConversation(Conversation conversation) async {
    final db = await database;
    await db.insert(
      'conversations',
      conversation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateConversationTitle(String id, String title) async {
    final db = await database;
    await db.update(
      'conversations',
      {'title': title, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Conversation>> getConversations() async {
    final db = await database;
    final maps = await db.query(
      'conversations',
      orderBy: 'is_pinned DESC, sort_order ASC, updated_at DESC',
    );
    return maps.map((map) => Conversation.fromMap(map)).toList();
  }

  Future<void> togglePinConversation(String id, bool isPinned) async {
    final db = await database;
    await db.update(
      'conversations',
      {'is_pinned': isPinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateConversationsOrder(List<Conversation> conversations) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < conversations.length; i++) {
      batch.update(
        'conversations',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [conversations[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteConversation(String id) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Messages ---
  
  Future<void> saveMessage(Message message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // Update conversation timestamp
    await db.update(
      'conversations',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [message.conversationId],
    );
  }

  /// Returns all messages for a conversation. 
  /// The UI controller is responsible for building the branching tree 
  /// and handling < 1/2 > traversal logic using parent_id.
  Future<List<Message>> getMessagesForConversation(String conversationId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<void> deleteMessage(String id) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns token usage statistics aggregated across all messages for today and overall.
  Future<TokenUsageStats> getTokenUsageStats() async {
    final db = await database;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day).toIso8601String();

    try {
      final todayRes = await db.rawQuery(
        'SELECT SUM(CASE WHEN tokens > 0 THEN tokens ELSE (LENGTH(content) / 3) END) as sum_tokens '
        'FROM messages WHERE created_at >= ?',
        [todayMidnight],
      );
      final totalRes = await db.rawQuery(
        'SELECT SUM(CASE WHEN tokens > 0 THEN tokens ELSE (LENGTH(content) / 3) END) as sum_tokens '
        'FROM messages',
      );

      final todayTokens = (todayRes.first['sum_tokens'] as num?)?.toInt() ?? 0;
      final totalTokens = (totalRes.first['sum_tokens'] as num?)?.toInt() ?? 0;

      return TokenUsageStats(
        todayTokens: todayTokens,
        totalTokens: totalTokens,
      );
    } catch (_) {
      return const TokenUsageStats();
    }
  }

  // --- Personas ---

  Future<List<Persona>> getPersonas() async {
    final db = await database;
    final maps = await db.query('personas');
    return maps.map((map) => Persona.fromMap(map)).toList();
  }

  Future<void> savePersona(Persona persona) async {
    final db = await database;
    await db.insert(
      'personas',
      persona.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Workspaces ---

  Future<List<Workspace>> getWorkspaces() async {
    final db = await database;
    final maps = await db.query(
      'workspaces',
      orderBy: 'is_pinned DESC, sort_order ASC, updated_at DESC',
    );
    return maps.map((m) => Workspace.fromMap(m)).toList();
  }

  Future<Workspace?> getWorkspace(String id) async {
    final db = await database;
    final maps = await db.query(
      'workspaces',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Workspace.fromMap(maps.first);
  }

  Future<void> saveWorkspace(Workspace ws) async {
    final db = await database;
    await db.insert(
      'workspaces',
      ws.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateWorkspacePrompt(String id, String prompt) async {
    final db = await database;
    await db.update(
      'workspaces',
      {'prompt': prompt, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateWorkspaceName(String id, String name) async {
    final db = await database;
    await db.update(
      'workspaces',
      {'name': name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> togglePinWorkspace(String id) async {
    final db = await database;
    final ws = await getWorkspace(id);
    if (ws == null) return;
    await db.update(
      'workspaces',
      {
        'is_pinned': ws.isPinned ? 0 : 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> reorderWorkspaces(int oldIndex, int newIndex) async {
    final db = await database;
    final workspaces = await getWorkspaces();
    if (oldIndex < 0 || oldIndex >= workspaces.length || newIndex < 0 || newIndex >= workspaces.length) {
      return;
    }
    final item = workspaces.removeAt(oldIndex);
    workspaces.insert(newIndex, item);
    final batch = db.batch();
    for (int i = 0; i < workspaces.length; i++) {
      batch.update(
        'workspaces',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [workspaces[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteWorkspace(String id) async {
    final db = await database;
    await db.delete(
      'workspace_context_files',
      where: 'workspace_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      'conversations',
      where: 'workspace_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      'workspaces',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Workspace Context Files ---

  Future<List<WorkspaceContextFile>> getWorkspaceFiles(String workspaceId) async {
    final db = await database;
    final maps = await db.query(
      'workspace_context_files',
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => WorkspaceContextFile.fromMap(m)).toList();
  }

  Future<void> addWorkspaceFile(WorkspaceContextFile file) async {
    final db = await database;
    await db.insert(
      'workspace_context_files',
      file.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.update(
      'workspaces',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [file.workspaceId],
    );
  }

  Future<void> deleteWorkspaceFile(String fileId) async {
    final db = await database;
    await db.delete(
      'workspace_context_files',
      where: 'id = ?',
      whereArgs: [fileId],
    );
  }

  // --- Workspace Conversations ---

  Future<List<Conversation>> getConversationsForWorkspace(String workspaceId) async {
    final db = await database;
    final maps = await db.query(
      'conversations',
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return maps.map((m) => Conversation.fromMap(m)).toList();
  }

  Future<List<Conversation>> getStandaloneConversations() async {
    final db = await database;
    final maps = await db.query(
      'conversations',
      where: 'workspace_id IS NULL',
      orderBy: 'is_pinned DESC, sort_order ASC, updated_at DESC',
    );
    return maps.map((m) => Conversation.fromMap(m)).toList();
  }

  Future<void> toggleWorkspaceContextForConversation(String conversationId, bool enabled) async {
    final db = await database;
    await db.update(
      'conversations',
      {'is_workspace_context_enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }
}
