import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class RepoMapService {
  static const Set<String> _supportedExtensions = {
    '.dart',
    '.py',
    '.ts',
    '.tsx',
    '.js',
    '.jsx',
    '.rs',
    '.go',
    '.java',
    '.kt',
  };

  /// Generates a compact structural code outline of key symbols (classes, functions)
  /// from the workspace files, strictly limited to [maxSymbols] to preserve token budget.
  static Future<String> generateRepoMap(
    String workspacePath,
    List<String> relativeFiles, {
    int maxSymbols = 80,
  }) async {
    final buffer = StringBuffer();
    int currentSymbols = 0;

    for (final relPath in relativeFiles) {
      if (currentSymbols >= maxSymbols) break;

      final ext = p.extension(relPath).toLowerCase();
      if (!_supportedExtensions.contains(ext)) continue;

      final fullPath = p.join(workspacePath, relPath);
      final file = File(fullPath);
      if (!await file.exists()) continue;

      try {
        final symbols = await _extractSymbols(file, ext);
        if (symbols.isNotEmpty) {
          buffer.writeln('- `$relPath`: ${symbols.join(', ')}');
          currentSymbols += symbols.length;
        }
      } catch (_) {
        // Skip unreadable files
      }
    }

    return buffer.toString().trim();
  }

  static Future<List<String>> _extractSymbols(File file, String ext) async {
    final List<String> symbols = [];
    final lines = await file
        .openRead()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .take(300)
        .toList();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('//') || trimmed.startsWith('#')) continue;

      if (ext == '.dart') {
        // Classes, enums, mixins
        final classMatch = RegExp(r'^(?:abstract\s+)?(?:class|enum|mixin|extension)\s+([A-Za-z0-9_]+)').firstMatch(trimmed);
        if (classMatch != null) {
          symbols.add(classMatch.group(1)!);
          continue;
        }
      } else if (ext == '.py') {
        // Classes and top-level functions
        final pyMatch = RegExp(r'^(?:class|def)\s+([A-Za-z0-9_]+)').firstMatch(trimmed);
        if (pyMatch != null) {
          symbols.add(pyMatch.group(1)!);
          continue;
        }
      } else if (ext == '.ts' || ext == '.tsx' || ext == '.js' || ext == '.jsx') {
        // Interfaces, types, classes, functions
        final tsMatch = RegExp(r'^(?:export\s+)?(?:default\s+)?(?:class|interface|type|enum)\s+([A-Za-z0-9_]+)').firstMatch(trimmed);
        if (tsMatch != null) {
          symbols.add(tsMatch.group(1)!);
          continue;
        }
      } else if (ext == '.rs') {
        // Structs, enums, traits
        final rsMatch = RegExp(r'^(?:pub\s+)?(?:struct|enum|trait)\s+([A-Za-z0-9_]+)').firstMatch(trimmed);
        if (rsMatch != null) {
          symbols.add(rsMatch.group(1)!);
          continue;
        }
      } else if (ext == '.go') {
        // Types, structs, funcs
        final goMatch = RegExp(r'^(?:type|func)\s+([A-Za-z0-9_]+)').firstMatch(trimmed);
        if (goMatch != null) {
          symbols.add(goMatch.group(1)!);
          continue;
        }
      }
    }

    return symbols.take(5).toList();
  }
}
