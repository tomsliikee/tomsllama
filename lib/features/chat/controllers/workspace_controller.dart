import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/attached_file.dart';
import '../../../core/models/workspace_info.dart';
import '../../../core/services/workspace_service.dart';

class WorkspaceState {
  final WorkspaceInfo? workspace;
  final List<AttachedFile> attachedFiles;
  final bool isLoading;

  const WorkspaceState({
    this.workspace,
    this.attachedFiles = const [],
    this.isLoading = false,
  });

  int get totalAttachedTokens =>
      attachedFiles.fold(0, (sum, f) => sum + f.estimatedTokens);

  WorkspaceState copyWith({
    WorkspaceInfo? workspace,
    bool clearWorkspace = false,
    List<AttachedFile>? attachedFiles,
    bool? isLoading,
  }) {
    return WorkspaceState(
      workspace: clearWorkspace ? null : (workspace ?? this.workspace),
      attachedFiles: attachedFiles ?? this.attachedFiles,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class WorkspaceNotifier extends StateNotifier<WorkspaceState> {
  WorkspaceNotifier() : super(const WorkspaceState());

  Future<void> setWorkspace(String directoryPath) async {
    state = state.copyWith(isLoading: true);
    final ws = await WorkspaceService.loadWorkspace(directoryPath);
    state = state.copyWith(
      workspace: ws,
      isLoading: false,
    );
  }

  void clearWorkspace() {
    state = state.copyWith(clearWorkspace: true);
  }

  Future<void> attachFiles(List<String> paths) async {
    final List<AttachedFile> newFiles = [...state.attachedFiles];
    final existingPaths = newFiles.map((f) => f.path).toSet();

    for (final path in paths) {
      if (existingPaths.contains(path)) continue;
      final file = await AttachedFile.fromPath(
        path,
        workspaceRoot: state.workspace?.path,
      );
      if (file != null) {
        newFiles.add(file);
        existingPaths.add(path);
      }
    }

    state = state.copyWith(attachedFiles: newFiles);
  }

  void removeAttachedFile(String path) {
    final updated = state.attachedFiles.where((f) => f.path != path).toList();
    state = state.copyWith(attachedFiles: updated);
  }

  void clearAttachments() {
    state = state.copyWith(attachedFiles: const []);
  }
}

final workspaceProvider =
    StateNotifierProvider<WorkspaceNotifier, WorkspaceState>((ref) {
  return WorkspaceNotifier();
});
