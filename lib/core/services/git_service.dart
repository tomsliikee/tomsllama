import 'dart:io';
import 'package:path/path.dart' as p;

class GitDetails {
  final String branch;
  final bool isDetached;

  const GitDetails({
    required this.branch,
    this.isDetached = false,
  });
}

class GitService {
  /// Detects git repository details for the given [directoryPath].
  /// Returns null if [directoryPath] is not inside a git repository.
  static Future<GitDetails?> getGitDetails(String directoryPath) async {
    // 1. Attempt using git CLI first if available
    try {
      final cliResult = await _detectViaCli(directoryPath);
      if (cliResult != null) {
        return cliResult;
      }
    } catch (_) {
      // CLI failed or unavailable; proceed to filesystem inspection fallback
    }

    // 2. Direct filesystem fallback (.git/HEAD)
    return _detectViaFilesystem(directoryPath);
  }

  static Future<GitDetails?> _detectViaCli(String directoryPath) async {
    // Check if inside work tree
    final checkResult = await Process.run(
      'git',
      ['rev-parse', '--is-inside-work-tree'],
      workingDirectory: directoryPath,
    ).timeout(const Duration(milliseconds: 600));

    if (checkResult.exitCode != 0 || (checkResult.stdout as String).trim() != 'true') {
      return null;
    }

    // Get current branch
    final branchResult = await Process.run(
      'git',
      ['branch', '--show-current'],
      workingDirectory: directoryPath,
    ).timeout(const Duration(milliseconds: 600));

    if (branchResult.exitCode == 0) {
      final branch = (branchResult.stdout as String).trim();
      if (branch.isNotEmpty) {
        return GitDetails(branch: branch, isDetached: false);
      }
    }

    // If branch is empty, check for detached HEAD
    final headResult = await Process.run(
      'git',
      ['rev-parse', '--short', 'HEAD'],
      workingDirectory: directoryPath,
    ).timeout(const Duration(milliseconds: 600));

    if (headResult.exitCode == 0) {
      final shortCommit = (headResult.stdout as String).trim();
      if (shortCommit.isNotEmpty) {
        return GitDetails(branch: shortCommit, isDetached: true);
      }
    }

    return null;
  }

  static Future<GitDetails?> _detectViaFilesystem(String directoryPath) async {
    Directory current = Directory(directoryPath);
    for (int i = 0; i < 5; i++) {
      final gitDir = Directory(p.join(current.path, '.git'));
      final gitFile = File(p.join(current.path, '.git'));

      if (await gitDir.exists()) {
        final headFile = File(p.join(gitDir.path, 'HEAD'));
        if (await headFile.exists()) {
          return _parseHeadFile(headFile);
        }
      } else if (await gitFile.exists()) {
        // Git worktree or submodule pointing to another gitdir
        try {
          final content = (await gitFile.readAsString()).trim();
          if (content.startsWith('gitdir:')) {
            String targetPath = content.substring(7).trim();
            if (!p.isAbsolute(targetPath)) {
              targetPath = p.normalize(p.join(current.path, targetPath));
            }
            final targetHead = File(p.join(targetPath, 'HEAD'));
            if (await targetHead.exists()) {
              return await _parseHeadFile(targetHead);
            }
          }
        } catch (_) {}
      }

      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }

    return null;
  }

  static Future<GitDetails?> _parseHeadFile(File headFile) async {
    try {
      final headContent = (await headFile.readAsString()).trim();
      if (headContent.startsWith('ref: refs/heads/')) {
        final branch = headContent.substring('ref: refs/heads/'.length).trim();
        return GitDetails(branch: branch, isDetached: false);
      } else if (headContent.length >= 7) {
        return GitDetails(
          branch: headContent.substring(0, 7),
          isDetached: true,
        );
      }
    } catch (_) {}
    return null;
  }
}
