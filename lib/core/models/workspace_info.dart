class WorkspaceInfo {
  final String path;
  final String name;
  final String? gitBranch;
  final bool isGitRepo;
  final List<String> files;

  const WorkspaceInfo({
    required this.path,
    required this.name,
    this.gitBranch,
    this.isGitRepo = false,
    this.files = const [],
  });

  String get formattedFileTree {
    if (files.isEmpty) return 'No files indexed.';
    final displayFiles = files.take(80).toList();
    final buffer = StringBuffer();
    for (final f in displayFiles) {
      buffer.writeln('- $f');
    }
    if (files.length > 80) {
      buffer.writeln('... and ${files.length - 80} more files');
    }
    return buffer.toString().trim();
  }

  WorkspaceInfo copyWith({
    String? path,
    String? name,
    String? gitBranch,
    bool? isGitRepo,
    List<String>? files,
  }) {
    return WorkspaceInfo(
      path: path ?? this.path,
      name: name ?? this.name,
      gitBranch: gitBranch ?? this.gitBranch,
      isGitRepo: isGitRepo ?? this.isGitRepo,
      files: files ?? this.files,
    );
  }
}
