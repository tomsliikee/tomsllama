import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/services/git_service.dart';
import 'package:tomsllama/core/services/workspace_service.dart';
import 'package:tomsllama/core/models/attached_file.dart';

void main() {
  group('GitService & WorkspaceService Tests', () {
    test('detects git repo and active branch on current repository', () async {
      final currentDir = Directory.current.path;
      final gitDetails = await GitService.getGitDetails(currentDir);

      expect(gitDetails, isNotNull);
      expect(gitDetails!.branch, isNotEmpty);
    });

    test('loads workspace and indexes files while ignoring build and .git', () async {
      final currentDir = Directory.current.path;
      final workspace = await WorkspaceService.loadWorkspace(currentDir);

      expect(workspace, isNotNull);
      expect(workspace!.name, equals('tomsllama'));
      expect(workspace.isGitRepo, isTrue);
      expect(workspace.gitBranch, isNotEmpty);
      expect(workspace.files, isNotEmpty);

      // Verify that files include pubspec.yaml and lib/main.dart
      expect(workspace.files.contains('pubspec.yaml'), isTrue);
      expect(workspace.files.any((f) => f.contains('main.dart')), isTrue);

      // Verify that ignored directories are excluded
      expect(workspace.files.any((f) => f.startsWith('.git/')), isFalse);
      expect(workspace.files.any((f) => f.startsWith('build/')), isFalse);
    });

    test('creates AttachedFile with token estimation and markdown block', () async {
      final filePath = '${Directory.current.path}/pubspec.yaml';
      final attached = await AttachedFile.fromPath(filePath, workspaceRoot: Directory.current.path);

      expect(attached, isNotNull);
      expect(attached!.name, equals('pubspec.yaml'));
      expect(attached.relativePath, equals('pubspec.yaml'));
      expect(attached.estimatedTokens, greaterThan(0));
      expect(attached.toMarkdownBlock(), contains('`pubspec.yaml`'));
      expect(attached.toMarkdownBlock(), contains('```yaml'));
    });

    test('loadDirectoryFiles loads code files from a directory as AttachedFiles with contents', () async {
      final libDir = '${Directory.current.path}/lib/core/constants';
      final files = await WorkspaceService.loadDirectoryFiles(libDir);

      expect(files, isNotEmpty);
      expect(files.any((f) => f.name.endsWith('.dart')), isTrue);
      expect(files.first.content, isNotEmpty);
      expect(files.first.estimatedTokens, greaterThan(0));
    });

    test('resolveInsideWorkspace refuses paths that leave the workspace', () async {
      final root = await Directory.systemTemp.createTemp('tomsllama_ws');
      final outside = await Directory.systemTemp.createTemp('tomsllama_outside');
      addTearDown(() async {
        await root.delete(recursive: true);
        await outside.delete(recursive: true);
      });
      await File('${root.path}/lib/a.dart').create(recursive: true);
      final secret = await File('${outside.path}/secret.txt').create();
      await Link('${root.path}/escape').create(outside.path);

      final inside = await WorkspaceService.resolveInsideWorkspace(root.path, 'lib/a.dart');
      expect(inside, '${root.path}/lib/a.dart');
      expect(await WorkspaceService.resolveInsideWorkspace(root.path, 'lib/../lib/a.dart'), inside);
      // A missing file inside the root is still a valid target; the read reports not-found.
      expect(await WorkspaceService.resolveInsideWorkspace(root.path, 'lib/missing.dart'), isNotNull);

      expect(await WorkspaceService.resolveInsideWorkspace(root.path, '../secret.txt'), isNull);
      expect(await WorkspaceService.resolveInsideWorkspace(root.path, 'lib/../../x'), isNull);
      expect(await WorkspaceService.resolveInsideWorkspace(root.path, secret.path), isNull);
      expect(await WorkspaceService.resolveInsideWorkspace(root.path, 'escape/secret.txt'), isNull);
      expect(await WorkspaceService.resolveInsideWorkspace(root.path, ''), isNull);
    });
  });
}
