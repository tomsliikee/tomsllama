import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/workspace_info.dart';
import 'git_service.dart';

class WorkspaceService {
  static const Set<String> ignoredDirNames = {
    '.git',
    'build',
    '.dart_tool',
    'node_modules',
    'dist',
    'target',
    '.idea',
    '.vscode',
    '.cache',
    '.venv',
    'venv',
    '__pycache__',
    '.gradle',
    'pods',
    '.symlinks',
    'bin',
    'obj',
  };

  static const Set<String> supportedCodeExtensions = {
    '.dart',
    '.py',
    '.js',
    '.jsx',
    '.ts',
    '.tsx',
    '.html',
    '.css',
    '.json',
    '.yaml',
    '.yml',
    '.toml',
    '.md',
    '.txt',
    '.rs',
    '.go',
    '.c',
    '.cpp',
    '.h',
    '.hpp',
    '.java',
    '.kt',
    '.swift',
    '.sql',
    '.sh',
    '.bash',
    '.zsh',
    '.xml',
    '.env',
    '.ini',
    '.conf',
    '.proto',
    '.gradle',
  };

  /// Loads and indexes a workspace directory, discovering files and git branch info.
  static Future<WorkspaceInfo?> loadWorkspace(
    String directoryPath, {
    int maxIndexedFiles = 1000,
  }) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return null;

    final dirName = p.basename(p.normalize(directoryPath));
    final gitDetails = await GitService.getGitDetails(directoryPath);

    final List<String> indexedFiles = [];

    try {
      await _scanDirectory(
        dir,
        directoryPath,
        indexedFiles,
        maxFiles: maxIndexedFiles,
      );
    } catch (_) {
      // In case of permission errors while traversing
    }

    indexedFiles.sort();

    return WorkspaceInfo(
      path: directoryPath,
      name: dirName.isEmpty ? directoryPath : dirName,
      gitBranch: gitDetails?.branch,
      isGitRepo: gitDetails != null,
      files: indexedFiles,
    );
  }

  static Future<void> _scanDirectory(
    Directory dir,
    String rootPath,
    List<String> results, {
    required int maxFiles,
  }) async {
    if (results.length >= maxFiles) return;

    try {
      final entries = await dir.list(followLinks: false).toList();
      for (final entry in entries) {
        if (results.length >= maxFiles) break;

        final basename = p.basename(entry.path);
        if (basename.startsWith('.') && basename != '.env') {
          if (basename != '.gitignore') continue;
        }

        if (entry is Directory) {
          if (ignoredDirNames.contains(basename.toLowerCase())) {
            continue;
          }
          await _scanDirectory(entry, rootPath, results, maxFiles: maxFiles);
        } else if (entry is File) {
          final ext = p.extension(entry.path).toLowerCase();
          final isNamedConfigFile = basename == 'Dockerfile' ||
              basename == 'Makefile' ||
              basename == '.gitignore' ||
              basename == 'pubspec.yaml';

          if (supportedCodeExtensions.contains(ext) || isNamedConfigFile) {
            final relPath = p.relative(entry.path, from: rootPath);
            results.add(relPath);
          }
        }
      }
    } catch (_) {
      // Ignore unreadable subdirectories
    }
  }
}
