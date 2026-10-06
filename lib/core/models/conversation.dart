class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int totalTokens;
  final bool isPinned;
  final int sortOrder;
  final String persona;
  final String? workspaceId;
  final bool isWorkspaceContextEnabled;

  /// Rolling summary of the turns up to and including [summaryThroughId].
  /// Those turns are no longer sent as history; the summary stands in for them.
  final String? summary;
  final String? summaryThroughId;

  /// Tokens the last answered turn occupied (prompt plus answer, as counted by
  /// Ollama) and the context window it ran in. Null until a turn has finished.
  /// Written only through [DatabaseService.updateConversationContext].
  final int? contextTokens;
  final int? contextWindow;

  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.totalTokens = 0,
    this.isPinned = false,
    this.sortOrder = 0,
    this.persona = 'Standard',
    this.workspaceId,
    this.isWorkspaceContextEnabled = true,
    this.summary,
    this.summaryThroughId,
    this.contextTokens,
    this.contextWindow,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'total_tokens': totalTokens,
      'is_pinned': isPinned ? 1 : 0,
      'sort_order': sortOrder,
      'persona': persona,
      'workspace_id': workspaceId,
      'is_workspace_context_enabled': isWorkspaceContextEnabled ? 1 : 0,
      'summary': summary,
      'summary_through_id': summaryThroughId,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      totalTokens: map['total_tokens'] as int? ?? 0,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      persona: (map['persona'] as String?) ?? 'Standard',
      workspaceId: map['workspace_id'] as String?,
      isWorkspaceContextEnabled: (map['is_workspace_context_enabled'] as int? ?? 1) == 1,
      summary: map['summary'] as String?,
      summaryThroughId: map['summary_through_id'] as String?,
      contextTokens: map['context_tokens'] as int?,
      contextWindow: map['context_window'] as int?,
    );
  }

  Conversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalTokens,
    bool? isPinned,
    int? sortOrder,
    String? persona,
    String? workspaceId,
    bool? isWorkspaceContextEnabled,
    String? summary,
    String? summaryThroughId,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalTokens: totalTokens ?? this.totalTokens,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      persona: persona ?? this.persona,
      workspaceId: workspaceId ?? this.workspaceId,
      isWorkspaceContextEnabled:
          isWorkspaceContextEnabled ?? this.isWorkspaceContextEnabled,
      summary: summary ?? this.summary,
      summaryThroughId: summaryThroughId ?? this.summaryThroughId,
      contextTokens: contextTokens,
      contextWindow: contextWindow,
    );
  }
}
