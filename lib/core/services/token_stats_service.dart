import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/token_usage_stats.dart';
import 'database_service.dart';

class TokenStatsNotifier extends StateNotifier<TokenUsageStats> {
  final DatabaseService _db;

  TokenStatsNotifier(this._db) : super(const TokenUsageStats()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final stats = await _db.getTokenUsageStats();
      if (mounted) {
        state = stats;
      }
    } catch (_) {
      // Graceful fallback for mock/test environments or uninitialized database
    }
  }
}

final tokenStatsProvider = StateNotifierProvider<TokenStatsNotifier, TokenUsageStats>((ref) {
  return TokenStatsNotifier(DatabaseService());
});
