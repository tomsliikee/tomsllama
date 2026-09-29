import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/context_manager.dart';
import '../services/pdf_service.dart';

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
    int maxSizeBytes = 500 * 1024,
    int maxLines = 500,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) return null;

    final ext = p.extension(filePath).toLowerCase();
    const binaryExtensions = {
      '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico',
      '.zip', '.tar', '.gz', '.7z', '.rar',
      '.exe', '.dll', '.so', '.dylib', '.bin',
      '.mp3', '.mp4', '.wav', '.mov', '.avi',
      '.db', '.sqlite', '.sqlite3',
    };
    if (binaryExtensions.contains(ext)) return null;

    final name = p.basename(filePath);
    final relPath = workspaceRoot != null && filePath.startsWith(workspaceRoot)
        ? p.relative(filePath, from: workspaceRoot)
        : name;

    // Handle PDF extraction via PdfService
    if (ext == '.pdf') {
      final pdfResult = await PdfService.extractText(filePath);
      if (pdfResult == null) return null;
      return AttachedFile(
        path: filePath,
        name: name,
        relativePath: relPath,
        sizeInBytes: stat.size,
        estimatedTokens: ContextManager.estimateTokens(pdfResult.text),
        content: pdfResult.text,
        extension: ext,
      );
    }

    try {
      final lines = <String>[];
      int totalLineCount = 0;
      bool isTruncated = false;

      final stream = file
          .openRead()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter());

      await for (final line in stream) {
        totalLineCount++;
        if (lines.length < maxLines) {
          lines.add(line);
        } else {
          isTruncated = true;
          if (totalLineCount >= maxLines + 200) {
            break;
          }
        }
      }

      String content = lines.join('\n');
      if (isTruncated) {
        content +=
            '\n\n// ... [Truncated: Showing first $maxLines lines of ${p.basename(filePath)} (~$totalLineCount+ total lines) for CPU performance] ...';
      }

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
      return null;
    }
  }

  /// Formatted markdown block for LLM prompt injection.
  String toMarkdownBlock() {
    if (extension == '.pdf') {
      return '[Attached PDF Document: $relativePath]\n```text\n$content\n```';
    }
    final lang = extension.startsWith('.') ? extension.substring(1) : extension;
    return '`$relativePath`\n```$lang\n$content\n```';
  }
}
