class Workspace {
  final String id;
  final String name;
  final String prompt;
  final bool isPinned;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Workspace({
    required this.id,
    required this.name,
    this.prompt = '',
    this.isPinned = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'prompt': prompt,
      'is_pinned': isPinned ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Workspace.fromMap(Map<String, dynamic> map) {
    return Workspace(
      id: map['id'] as String,
      name: map['name'] as String,
      prompt: (map['prompt'] as String?) ?? '',
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Workspace copyWith({
    String? id,
    String? name,
    String? prompt,
    bool? isPinned,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      prompt: prompt ?? this.prompt,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
