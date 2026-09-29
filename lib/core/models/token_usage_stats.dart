import '../services/localization_service.dart';

class TokenUsageStats {
  final int todayTokens;
  final int totalTokens;

  const TokenUsageStats({
    this.todayTokens = 0,
    this.totalTokens = 0,
  });

  String get todayFormatted {
    final str = todayTokens >= 1000
        ? '~${(todayTokens / 1000).toStringAsFixed(1)}k'
        : '$todayTokens';
    return I18n.isGerman ? '$str Tokens heute' : '$str tokens today';
  }

  String get totalFormatted {
    final str = totalTokens >= 1000
        ? '~${(totalTokens / 1000).toStringAsFixed(1)}k'
        : '$totalTokens';
    return I18n.isGerman ? '$str Tokens gesamt' : '$str tokens total';
  }
}
