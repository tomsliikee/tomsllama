import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/conversation.dart';
import '../../../../core/services/database_service.dart';

class SidebarState {
  final List<Conversation> conversations;
  final String searchQuery;
  final String? activeConversationId;
  final bool isLoading;

  const SidebarState({
    this.conversations = const [],
    this.searchQuery = '',
    this.activeConversationId,
    this.isLoading = false,
  });

  List<Conversation> get filteredConversations {
    if (searchQuery.trim().isEmpty) return conversations;
    final query = searchQuery.toLowerCase();
    return conversations
        .where((c) => c.title.toLowerCase().contains(query))
        .toList();
  }

  SidebarState copyWith({
    List<Conversation>? conversations,
    String? searchQuery,
    String? activeConversationId,
    bool? isLoading,
  }) {
    return SidebarState(
      conversations: conversations ?? this.conversations,
      searchQuery: searchQuery ?? this.searchQuery,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SidebarNotifier extends StateNotifier<SidebarState> {
  final DatabaseService _db = DatabaseService();

  SidebarNotifier() : super(const SidebarState()) {
    loadConversations();
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true);
    final list = await _db.getConversations();
    state = state.copyWith(
      conversations: list,
      isLoading: false,
      activeConversationId: state.activeConversationId ?? (list.isNotEmpty ? list.first.id : null),
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setActiveConversation(String id) {
    state = state.copyWith(activeConversationId: id);
  }

  Future<void> deleteConversation(String id) async {
    await _db.deleteConversation(id);
    final updatedList = state.conversations.where((c) => c.id != id).toList();
    String? nextActive = state.activeConversationId;
    if (nextActive == id) {
      nextActive = updatedList.isNotEmpty ? updatedList.first.id : null;
    }
    state = state.copyWith(
      conversations: updatedList,
      activeConversationId: nextActive,
    );
  }

  Future<Conversation> createNewConversation({
    String title = 'Neuer Chat',
    String persona = 'Standard',
  }) async {
    final now = DateTime.now();
    final newConv = Conversation(
      id: now.millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: now,
      updatedAt: now,
      persona: persona,
    );
    await _db.saveConversation(newConv);
    final updatedList = [newConv, ...state.conversations];
    state = state.copyWith(
      conversations: updatedList,
      activeConversationId: newConv.id,
    );
    return newConv;
  }

  Future<void> updateTitle(String id, String title) async {
    await _db.updateConversationTitle(id, title);
    final updatedList = state.conversations.map((c) {
      if (c.id == id) {
        return c.copyWith(title: title);
      }
      return c;
    }).toList();
    state = state.copyWith(conversations: updatedList);
  }

  Future<void> updatePersona(String id, String persona) async {
    await _db.updateConversationPersona(id, persona);
    final updatedList = state.conversations.map((c) {
      if (c.id == id) {
        return c.copyWith(persona: persona);
      }
      return c;
    }).toList();
    state = state.copyWith(conversations: updatedList);
  }

  Future<void> togglePin(String id) async {
    final index = state.conversations.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final current = state.conversations[index];
    final newPinned = !current.isPinned;
    await _db.togglePinConversation(id, newPinned);

    final updated = List<Conversation>.from(state.conversations);
    updated[index] = current.copyWith(isPinned: newPinned);
    _sortConversations(updated);

    state = state.copyWith(conversations: updated);
    await _db.updateConversationsOrder(updated);
  }

  Future<void> reorderConversations(int oldIndex, int newIndex) async {
    if (state.searchQuery.trim().isNotEmpty) return;
    if (oldIndex < 0 || oldIndex >= state.conversations.length) return;
    if (newIndex < 0 || newIndex >= state.conversations.length) return;

    final list = List<Conversation>.from(state.conversations);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    state = state.copyWith(conversations: list);
    await _db.updateConversationsOrder(list);
  }

  void _sortConversations(List<Conversation> list) {
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }
}

final sidebarProvider = StateNotifierProvider<SidebarNotifier, SidebarState>((ref) {
  return SidebarNotifier();
});
