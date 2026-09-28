import 'dart:convert';
import 'dart:io';
import 'package:markdown/markdown.dart' as md;
import '../models/conversation.dart';
import '../models/message.dart';
import 'localization_service.dart';

class ExportService {
  static Future<bool> exportToMarkdown(Conversation conversation, List<Message> messages, String path) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('# ${conversation.title}');
      buffer.writeln('_Generated with tomsllama (Local AI)_\n');

      for (final msg in messages) {
        if (msg.role == 'system') continue; // usually skip system prompts in export
        
        final roleName = msg.role == 'user' ? I18n.you : I18n.assistant;
        buffer.writeln('### $roleName');
        
        if (msg.thinkContent != null && msg.thinkContent!.isNotEmpty) {
          buffer.writeln('<details><summary>${I18n.thoughtProcess}</summary>');
          buffer.writeln(msg.thinkContent);
          buffer.writeln('</details>\n');
        }
        
        buffer.writeln(msg.content);
        buffer.writeln('\n---\n');
      }

      await File(path).writeAsString(buffer.toString());
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> exportToJson(Conversation conversation, List<Message> messages, String path) async {
    try {
      final data = {
        'id': conversation.id,
        'title': conversation.title,
        'createdAt': conversation.createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toMap()).toList(),
      };
      
      const encoder = JsonEncoder.withIndent('  ');
      await File(path).writeAsString(encoder.convert(data));
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> exportToHtml(Conversation conversation, List<Message> messages, String path) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('<!DOCTYPE html>');
      buffer.writeln('<html><head><title>${conversation.title}</title>');
      buffer.writeln('<style>body { font-family: sans-serif; max-width: 800px; margin: 2rem auto; line-height: 1.6; } .message { margin-bottom: 2rem; padding: 1rem; border-radius: 8px; } .user { background: #f0f0f0; } .assistant { background: #e0f0ff; } pre { background: #222; color: #fff; padding: 1rem; border-radius: 4px; overflow-x: auto; }</style>');
      buffer.writeln('</head><body>');
      buffer.writeln('<h1>${conversation.title}</h1>');

      for (final msg in messages) {
        if (msg.role == 'system') continue;
        
        final cssClass = msg.role == 'user' ? 'user' : 'assistant';
        final roleName = msg.role == 'user' ? I18n.you : I18n.assistant;
        
        buffer.writeln('<div class="message $cssClass">');
        buffer.writeln('<strong>$roleName</strong><br/><br/>');
        
        // Use markdown package to parse content to HTML
        final htmlContent = md.markdownToHtml(msg.content);
            
        buffer.writeln('<div>$htmlContent</div>');
        buffer.writeln('</div>');
      }

      buffer.writeln('</body></html>');
      
      await File(path).writeAsString(buffer.toString());
      return true;
    } catch (e) {
      return false;
    }
  }
}
