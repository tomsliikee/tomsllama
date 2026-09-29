import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/services/repo_map_service.dart';

void main() {
  test('RepoMapService extracts symbols from files into a compact outline', () async {
    final currentDir = Directory.current.path;
    final testFiles = [
      'lib/core/services/git_service.dart',
      'lib/core/services/context_manager.dart',
      'lib/core/models/attached_file.dart',
    ];

    final repoMap = await RepoMapService.generateRepoMap(
      currentDir,
      testFiles,
      maxSymbols: 30,
    );

    expect(repoMap, isNotEmpty);
    expect(repoMap, contains('GitService'));
    expect(repoMap, contains('ContextManager'));
    expect(repoMap, contains('AttachedFile'));
  });
}
