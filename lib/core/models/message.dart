class Message {
  final String id;
  final String conversationId;
  final String? parentId; // Used for branching (< 1/2 >)
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final String? thinkContent; // Content inside <think> tags
  final DateTime createdAt;
  final int tokens;
  final int generationDurationMs;

  const Message({
    required this.id,
    required this.conversationId,
    this.parentId,
    required this.role,
    required this.content,
    this.thinkContent,
    required this.createdAt,
    this.tokens = 0,
    this.generationDurationMs = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'parent_id': parentId,
      'role': role,
      'content': content,
      'think_content': thinkContent,
      'created_at': createdAt.toIso8601String(),
      'tokens': tokens,
      'generation_duration_ms': generationDurationMs,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      parentId: map['parent_id'] as String?,
      role: map['role'] as String,
      content: map['content'] as String,
      thinkContent: map['think_content'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      tokens: map['tokens'] as int? ?? 0,
      generationDurationMs: map['generation_duration_ms'] as int? ?? 0,
    );
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? parentId,
    String? role,
    String? content,
    String? thinkContent,
    DateTime? createdAt,
    int? tokens,
    int? generationDurationMs,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      parentId: parentId ?? this.parentId,
      role: role ?? this.role,
      content: content ?? this.content,
      thinkContent: thinkContent ?? this.thinkContent,
      createdAt: createdAt ?? this.createdAt,
      tokens: tokens ?? this.tokens,
      generationDurationMs: generationDurationMs ?? this.generationDurationMs,
    );
  }
}
