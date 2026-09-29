import 'package:path/path.dart' as p;

class WorkspaceContextFile {
  final String id;
  final String workspaceId;
  final String filePath;
  final String fileName;
  final int fileSize;
  final String content;
  final int estimatedTokens;
  final DateTime createdAt;

  const WorkspaceContextFile({
    required this.id,
    required this.workspaceId,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.content,
    required this.estimatedTokens,
    required this.createdAt,
  });

  String get extension => p.extension(fileName).toLowerCase();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workspace_id': workspaceId,
      'file_path': filePath,
      'file_name': fileName,
      'file_size': fileSize,
      'content': content,
      'estimated_tokens': estimatedTokens,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WorkspaceContextFile.fromMap(Map<String, dynamic> map) {
    return WorkspaceContextFile(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      filePath: map['file_path'] as String,
      fileName: map['file_name'] as String,
      fileSize: map['file_size'] as int? ?? 0,
      content: (map['content'] as String?) ?? '',
      estimatedTokens: map['estimated_tokens'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Formatted markdown block for LLM prompt context injection.
  String toMarkdownBlock() {
    if (extension == '.pdf') {
      return '[Workspace Knowledge PDF: $fileName]\n```text\n$content\n```';
    }
    final lang = extension.startsWith('.') ? extension.substring(1) : extension;
    return '`$fileName`\n```$lang\n$content\n```';
  }
}
