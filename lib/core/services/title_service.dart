import 'dart:async';
import 'ollama_service.dart';
import '../models/message.dart';
import 'localization_service.dart';

class TitleService {
  static const String summarizerModel = 'qwen2.5-coder:1.5b'; // Fast small model
  static const int maxTitleLength = 40;

  static Future<String> generateTitle(List<Message> messages, {String? modelOverride}) async {
    // Only use the first 2-3 messages for context
    final contextMessages = messages.where((m) => m.role != 'system').take(3).toList();
    if (contextMessages.isEmpty) return I18n.newChatTitle;

    // Build prompt
    final prompt = 'Summarize the user\'s intent in 3-5 words. Do not use quotes or punctuation. Be direct. User said: "${contextMessages.first.content}"';

    try {
      final stream = OllamaService().streamChat(
        modelOverride ?? summarizerModel,
        [
          {'role': 'user', 'content': prompt}
        ],
      );

      final buffer = StringBuffer();
      await for (final chunk in stream) {
        if (!chunk.startsWith('Error:')) {
          buffer.write(chunk);
          if (buffer.length > maxTitleLength) {
            break; // Stop listening early
          }
        }
      }

      final title = buffer.toString().trim().replaceAll('"', '');
      return title.isEmpty ? I18n.newChatTitle : _truncate(title);
    } catch (e) {
      // Fallback
      return _truncate(contextMessages.first.content);
    }
  }

  static String _truncate(String text) {
    if (text.length <= maxTitleLength) return text;
    return '${text.substring(0, maxTitleLength - 3)}...';
  }
}
