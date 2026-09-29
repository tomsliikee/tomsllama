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
    int maxLines = 1500,
    int maxChars = 60000,
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
      int totalChars = 0;
      bool isTruncated = false;

      final stream = file
          .openRead()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter());

      await for (final line in stream) {
        totalLineCount++;
        if (lines.length < maxLines && totalChars + line.length <= maxChars) {
          lines.add(line);
          totalChars += line.length;
        } else {
          isTruncated = true;
          if (totalLineCount >= maxLines + 50) {
            break;
          }
        }
      }

      String content = lines.join('\n');
      if (isTruncated) {
        content +=
            '\n\n// ... [Gekürzt: Zeige erste ${lines.length} Zeilen von ${p.basename(filePath)} (~$totalLineCount Zeilen gesamt) für optimale CPU-Antwortzeit] ...';
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

  /// Formatted markdown block for LLM prompt injection with CPU-safe bounds.
  String toMarkdownBlock({int maxLines = 1500}) {
    if (extension == '.pdf') {
      return '[Attached PDF Document: $relativePath]\n```text\n$content\n```';
    }
    final lang = extension.startsWith('.') ? extension.substring(1) : extension;
    final lines = content.split('\n');
    String effectiveContent = content;
    if (lines.length > maxLines) {
      final truncatedBody = lines.take(maxLines).join('\n');
      effectiveContent = '$truncatedBody\n\n// ... [Gekürzt: Zeige erste $maxLines Zeilen von $name (${lines.length} Zeilen gesamt) für optimale CPU-Antwortzeit]';
    }
    return '`$relativePath`\n```$lang\n$effectiveContent\n```';
  }
}
