import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/conversation.dart';
import '../../../core/models/workspace.dart';
import '../../../core/models/workspace_context_file.dart';
import '../../../core/services/context_manager.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/pdf_service.dart';

enum SidebarMode { chats, workspaces }

final sidebarModeProvider = StateProvider<SidebarMode>((ref) => SidebarMode.chats);

class WorkspaceListState {
  final List<Workspace> workspaces;
  final String? activeWorkspaceId;
  final String searchQuery;
  final bool isLoading;

  const WorkspaceListState({
    this.workspaces = const [],
    this.activeWorkspaceId,
    this.searchQuery = '',
    this.isLoading = false,
  });

  List<Workspace> get filteredWorkspaces {
    if (searchQuery.trim().isEmpty) return workspaces;
    final q = searchQuery.toLowerCase().trim();
    return workspaces.where((w) => w.name.toLowerCase().contains(q)).toList();
  }

  Workspace? get activeWorkspace {
    if (activeWorkspaceId == null) return null;
    return workspaces.where((w) => w.id == activeWorkspaceId).firstOrNull;
  }

  WorkspaceListState copyWith({
    List<Workspace>? workspaces,
    String? activeWorkspaceId,
    bool clearActiveWorkspace = false,
    String? searchQuery,
    bool? isLoading,
  }) {
    return WorkspaceListState(
      workspaces: workspaces ?? this.workspaces,
      activeWorkspaceId: clearActiveWorkspace
          ? null
          : (activeWorkspaceId ?? this.activeWorkspaceId),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class WorkspaceListNotifier extends StateNotifier<WorkspaceListState> {
  final DatabaseService _db = DatabaseService();

  WorkspaceListNotifier() : super(const WorkspaceListState());

  Future<void> loadWorkspaces() async {
    state = state.copyWith(isLoading: true);
    final list = await _db.getWorkspaces();
    state = state.copyWith(workspaces: list, isLoading: false);
  }

  void setActiveWorkspace(String? id) {
    state = state.copyWith(
      activeWorkspaceId: id,
      clearActiveWorkspace: id == null,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<Workspace> createNewWorkspace({
    required String name,
    String prompt = '',
  }) async {
    final now = DateTime.now();
    final ws = Workspace(
      id: '${now.millisecondsSinceEpoch}_ws',
      name: name.trim().isEmpty ? 'Neuer Workspace' : name.trim(),
      prompt: prompt,
      createdAt: now,
      updatedAt: now,
    );
    await _db.saveWorkspace(ws);
    await loadWorkspaces();
    setActiveWorkspace(ws.id);
    return ws;
  }

  Future<void> updateWorkspaceName(String id, String name) async {
    await _db.updateWorkspaceName(id, name);
    await loadWorkspaces();
  }

  Future<void> updateWorkspacePrompt(String id, String prompt) async {
    await _db.updateWorkspacePrompt(id, prompt);
    await loadWorkspaces();
  }

  Future<void> togglePin(String id) async {
    await _db.togglePinWorkspace(id);
    await loadWorkspaces();
  }

  Future<void> reorderWorkspaces(int oldIndex, int newIndex) async {
    await _db.reorderWorkspaces(oldIndex, newIndex);
    await loadWorkspaces();
  }

  Future<void> deleteWorkspace(String id) async {
    await _db.deleteWorkspace(id);
    if (state.activeWorkspaceId == id) {
      state = state.copyWith(clearActiveWorkspace: true);
    }
    await loadWorkspaces();
  }
}

final workspaceListProvider =
    StateNotifierProvider<WorkspaceListNotifier, WorkspaceListState>((ref) {
  return WorkspaceListNotifier();
});

class ActiveWorkspaceState {
  final Workspace? workspace;
  final List<WorkspaceContextFile> files;
  final List<Conversation> chats;
  final bool isLoading;

  const ActiveWorkspaceState({
    this.workspace,
    this.files = const [],
    this.chats = const [],
    this.isLoading = false,
  });

  int get totalEstimatedTokens {
    int sum = 0;
    if (workspace != null && workspace!.prompt.isNotEmpty) {
      sum += ContextManager.estimateTokens(workspace!.prompt);
    }
    for (final f in files) {
      sum += f.estimatedTokens;
    }
    return sum;
  }

  ActiveWorkspaceState copyWith({
    Workspace? workspace,
    bool clearWorkspace = false,
    List<WorkspaceContextFile>? files,
    List<Conversation>? chats,
    bool? isLoading,
  }) {
    return ActiveWorkspaceState(
      workspace: clearWorkspace ? null : (workspace ?? this.workspace),
      files: files ?? this.files,
      chats: chats ?? this.chats,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ActiveWorkspaceNotifier extends StateNotifier<ActiveWorkspaceState> {
  final DatabaseService _db = DatabaseService();
  final Ref _ref;

  ActiveWorkspaceNotifier(this._ref) : super(const ActiveWorkspaceState());

  Future<void> loadWorkspace(String workspaceId) async {
    state = state.copyWith(isLoading: true);
    final ws = await _db.getWorkspace(workspaceId);
    if (ws == null) {
      state = const ActiveWorkspaceState();
      return;
    }
    final files = await _db.getWorkspaceFiles(workspaceId);
    final chats = await _db.getConversationsForWorkspace(workspaceId);
    state = ActiveWorkspaceState(
      workspace: ws,
      files: files,
      chats: chats,
      isLoading: false,
    );
  }

  Future<void> refresh() async {
    if (state.workspace == null) return;
    await loadWorkspace(state.workspace!.id);
  }

  Future<void> updatePrompt(String newPrompt) async {
    if (state.workspace == null) return;
    final wsId = state.workspace!.id;
    await _db.updateWorkspacePrompt(wsId, newPrompt);
    final updatedWs = state.workspace!.copyWith(prompt: newPrompt, updatedAt: DateTime.now());
    state = state.copyWith(workspace: updatedWs);
    _ref.read(workspaceListProvider.notifier).loadWorkspaces();
  }

  Future<void> updateName(String newName) async {
    if (state.workspace == null) return;
    final wsId = state.workspace!.id;
    await _db.updateWorkspaceName(wsId, newName);
    final updatedWs = state.workspace!.copyWith(name: newName, updatedAt: DateTime.now());
    state = state.copyWith(workspace: updatedWs);
    _ref.read(workspaceListProvider.notifier).loadWorkspaces();
  }

  Future<bool> addFileFromPath(String filePath) async {
    if (state.workspace == null) return false;
    final file = File(filePath);
    if (!await file.exists()) return false;

    final wsId = state.workspace!.id;
    final name = p.basename(filePath);
    final ext = p.extension(filePath).toLowerCase();
    final stat = await file.stat();

    String content = '';
    int tokens = 0;

    if (ext == '.pdf') {
      final pdfResult = await PdfService.extractText(filePath);
      if (pdfResult == null) return false;
      content = pdfResult.text;
      tokens = ContextManager.estimateTokens(content);
    } else {
      try {
        final lines = await file
            .openRead()
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .toList();

        const maxLines = 400;
        if (lines.length > maxLines) {
          final truncated = lines.take(maxLines).join('\n');
          content = '$truncated\n\n// ... [Truncated: Showing first $maxLines lines of $name (${lines.length} total lines) for CPU performance] ...';
        } else {
          content = lines.join('\n');
        }
        tokens = ContextManager.estimateTokens(content);
      } catch (_) {
        return false;
      }
    }

    final now = DateTime.now();
    final ctxFile = WorkspaceContextFile(
      id: '${now.millisecondsSinceEpoch}_${name.hashCode}',
      workspaceId: wsId,
      filePath: filePath,
      fileName: name,
      fileSize: stat.size,
      content: content,
      estimatedTokens: tokens,
      createdAt: now,
    );

    await _db.addWorkspaceFile(ctxFile);
    await refresh();
    return true;
  }

  Future<void> removeFile(String fileId) async {
    await _db.deleteWorkspaceFile(fileId);
    await refresh();
  }

  void clear() {
    state = const ActiveWorkspaceState();
  }
}

final activeWorkspaceProvider =
    StateNotifierProvider<ActiveWorkspaceNotifier, ActiveWorkspaceState>((ref) {
  return ActiveWorkspaceNotifier(ref);
});
