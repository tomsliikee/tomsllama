import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/context_manager.dart';

class AttachedFile {
  final String path;
  final String name;
  final String relativePath;
  final int sizeInBytes;
  final int estimatedTokens;
  final String content;
  final String extension;

  const AttachedFile({
    required this.path,
    required this.name,
    required this.relativePath,
    required this.sizeInBytes,
    required this.estimatedTokens,
    required this.content,
    required this.extension,
  });

  /// Factory to construct an AttachedFile from disk safely with size limits.
  static Future<AttachedFile?> fromPath(
    String filePath, {
    String? workspaceRoot,
    int maxSizeBytes = 300 * 1024, // 300 KB limit for single file
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) return null;
    if (stat.size > maxSizeBytes) {
      // Too large for prompt injection
      return null;
    }

    try {
      final content = await file.readAsString();
      final name = p.basename(filePath);
      final relPath = workspaceRoot != null && filePath.startsWith(workspaceRoot)
          ? p.relative(filePath, from: workspaceRoot)
          : name;
      final ext = p.extension(filePath).toLowerCase();

      return AttachedFile(
        path: filePath,
        name: name,
        relativePath: relPath,
        sizeInBytes: stat.size,
        estimatedTokens: ContextManager.estimateTokens(content),
        content: content,
        extension: ext,
      );
    } catch (_) {
      // Non-utf8 binary or permission issue
      return null;
    }
  }

  /// Formatted markdown block for LLM prompt injection.
  String toMarkdownBlock() {
    final lang = extension.startsWith('.') ? extension.substring(1) : extension;
    return '`$relativePath`\n```$lang\n$content\n```';
  }
}
