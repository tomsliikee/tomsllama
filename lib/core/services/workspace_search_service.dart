import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/attached_file.dart';

class WorkspaceSearchService {
  static const Set<String> _stopWords = {
    'the', 'and', 'for', 'with', 'what', 'which', 'where', 'when', 'how', 'does',
    'wie', 'wo', 'was', 'ist', 'sind', 'der', 'die', 'das', 'ein', 'eine', 'einen',
    'mit', 'und', 'oder', 'fuer', 'nach', 'beim', 'behebe', 'mache', 'zeig', 'kann',
    'bitte', 'schau', 'code', 'file', 'datei',
  };

  /// Searches the workspace files for relevant code matching the user's query keywords.
  /// Returns at most [maxResults] AttachedFile instances, scored and filtered.
  static Future<List<AttachedFile>> searchRelevantFiles(
    String query,
    String workspacePath,
    List<String> indexedFiles, {
    Set<String>? excludedPaths,
    int maxResults = 2,
  }) async {
    final queryTokens = _tokenizeQuery(query);
    if (queryTokens.isEmpty) return [];

    final scoredFiles = <_ScoredPath>[];
    final exclude = excludedPaths ?? <String>{};

    for (final relPath in indexedFiles) {
      final fullPath = p.join(workspacePath, relPath);
      if (exclude.contains(fullPath) || exclude.contains(relPath)) continue;

      int score = 0;
      final basenameLower = p.basename(relPath).toLowerCase();
      final relLower = relPath.toLowerCase();

      for (final token in queryTokens) {
        if (basenameLower == token || basenameLower.startsWith(token)) {
          score += 10;
        } else if (basenameLower.contains(token)) {
          score += 6;
        } else if (relLower.contains(token)) {
          score += 4;
        }
      }

      // Check first 80 lines for content keywords if base score > 0 or token has >= 4 chars
      if (score > 0 || queryTokens.any((t) => t.length >= 4)) {
        final contentMatches = await _checkContentMatches(fullPath, queryTokens);
        score += contentMatches * 2;
      }

      if (score >= 4) {
        scoredFiles.add(_ScoredPath(fullPath: fullPath, relPath: relPath, score: score));
      }
    }

    scoredFiles.sort((a, b) => b.score.compareTo(a.score));

    final results = <AttachedFile>[];
    for (final candidate in scoredFiles.take(maxResults)) {
      final attached = await AttachedFile.fromPath(
        candidate.fullPath,
        workspaceRoot: workspacePath,
        maxLines: 250,
      );
      if (attached != null) {
        results.add(attached);
      }
    }

    return results;
  }

  static List<String> _tokenizeQuery(String query) {
    final cleaned = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_äöüß]'), ' ');
    final rawTokens = cleaned.split(RegExp(r'\s+'));
    return rawTokens
        .where((t) => t.length >= 3 && !_stopWords.contains(t))
        .toSet()
        .toList();
  }

  static Future<int> _checkContentMatches(String filePath, List<String> tokens) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;

    int matches = 0;
    try {
      final lines = await file
          .openRead()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .take(80)
          .toList();

      for (final line in lines) {
        final lineLower = line.toLowerCase();
        for (final token in tokens) {
          if (lineLower.contains(token)) {
            matches++;
            if (matches >= 3) return matches;
          }
        }
      }
    } catch (_) {
      // Skip unreadable files
    }

    return matches;
  }
}

class _ScoredPath {
  final String fullPath;
  final String relPath;
  final int score;

  const _ScoredPath({
    required this.fullPath,
    required this.relPath,
    required this.score,
  });
}
