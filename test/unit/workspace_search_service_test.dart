import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/services/workspace_search_service.dart';

void main() {
  test('WorkspaceSearchService finds relevant files based on user query tokens', () async {
    final currentDir = Directory.current.path;
    final testFiles = [
      'lib/core/services/git_service.dart',
      'lib/core/services/context_manager.dart',
      'lib/core/services/database_service.dart',
    ];

    final results = await WorkspaceSearchService.searchRelevantFiles(
      'Wie funktioniert die git branch erkennung?',
      currentDir,
      testFiles,
      maxResults: 1,
    );

    expect(results, isNotEmpty);
    expect(results.first.name, equals('git_service.dart'));
    expect(results.first.content, contains('GitService'));
  });
}
