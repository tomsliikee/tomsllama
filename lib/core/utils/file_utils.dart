import 'dart:io';
import 'package:path/path.dart' as p;

class FileUtils {
  static const List<String> supportedExtensions = ['.txt', '.md', '.json', '.yaml', '.yml', '.py', '.dart', '.js', '.ts', '.html', '.css', '.cpp', '.c', '.h', '.java', '.go', '.rs'];

  /// Reads a file and returns its content wrapped in a Markdown code block
  /// with the appropriate language tag and filename comment.
  static Future<String?> readFileAsMarkdown(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final ext = p.extension(filePath).toLowerCase();
    
    // We only process plain text / code files.
    if (!supportedExtensions.contains(ext)) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final filename = p.basename(filePath);
      final lang = ext.isNotEmpty ? ext.substring(1) : '';

      return '\n`$filename`\n```$lang\n$content\n```\n';
    } catch (e) {
      // Return null if it's a binary file disguised with a text extension or permission error
      return null;
    }
  }
}
