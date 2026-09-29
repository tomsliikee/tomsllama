import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/ollama_model.dart';
import '../models/pull_progress.dart';

class OllamaService {
  static final OllamaService _instance = OllamaService._internal();
  factory OllamaService() => _instance;
  OllamaService._internal();

  String baseUrl = 'http://localhost:11434';

  Future<List<OllamaModel>> listModels() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/tags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List).map((e) => OllamaModel.fromJson(e)).toList();
        return models;
      }
    } catch (e) {
      // Ignored for now, handled by UI
    }
    return [];
  }

  Stream<String> streamChat(
    String model,
    List<Map<String, dynamic>> messages, {
    double? temperature,
    int? numCtx,
    List<Map<String, dynamic>>? tools,
    void Function(Map<String, dynamic> toolCall)? onToolCall,
  }) async* {
    final client = http.Client();
    final request = http.Request('POST', Uri.parse('$baseUrl/api/chat'));
    request.headers['Content-Type'] = 'application/json';
    final payload = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': true,
    };
    if (tools != null && tools.isNotEmpty) {
      payload['tools'] = tools;
    }
    final options = <String, dynamic>{};
    if (temperature != null) {
      options['temperature'] = temperature;
    }
    if (numCtx != null) {
      options['num_ctx'] = numCtx;
    }
    if (options.isNotEmpty) {
      payload['options'] = options;
    }
    request.body = jsonEncode(payload);

    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw HttpException('Ollama returned HTTP ${response.statusCode}');
      }

      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        try {
          final data = jsonDecode(line);
          final msg = data['message'];
          if (msg != null && msg is Map<String, dynamic>) {
            // Check for native tool calls or json tool call in content
            final toolCall = _extractToolCall(msg);
            if (toolCall != null) {
              onToolCall?.call(toolCall);
            }

            if (msg['content'] != null) {
              final content = msg['content'] as String;
              if (content.isNotEmpty && toolCall == null) {
                yield content;
              }
            }
          }
        } catch (_) {
          // Ignore incomplete non-json line
        }
      }
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic>? _extractToolCall(Map<String, dynamic> message) {
    if (message['tool_calls'] != null && (message['tool_calls'] as List).isNotEmpty) {
      return (message['tool_calls'] as List).first as Map<String, dynamic>;
    }
    final content = message['content'];
    if (content is String && content.trim().startsWith('{') && content.trim().endsWith('}')) {
      try {
        final parsed = jsonDecode(content.trim());
        if (parsed is Map<String, dynamic> && parsed.containsKey('name')) {
          return {
            'function': {
              'name': parsed['name'],
              'arguments': parsed['arguments'] ?? {},
            }
          };
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>?> chatTurn(
    String model,
    List<Map<String, dynamic>> messages, {
    double? temperature,
    int? numCtx,
    List<Map<String, dynamic>>? tools,
  }) async {
    final client = http.Client();
    try {
      final payload = <String, dynamic>{
        'model': model,
        'messages': messages,
        'stream': false,
      };
      if (tools != null && tools.isNotEmpty) {
        payload['tools'] = tools;
      }
      final options = <String, dynamic>{};
      if (temperature != null) options['temperature'] = temperature;
      if (numCtx != null) options['num_ctx'] = numCtx;
      if (options.isNotEmpty) payload['options'] = options;

      final res = await client.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['message'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Stream<PullProgress> pullModelStream(String modelName) async* {
    final client = http.Client();
    final request = http.Request('POST', Uri.parse('$baseUrl/api/pull'));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({'name': modelName, 'stream': true});

    try {
      final response = await client.send(request);
      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        try {
          final data = jsonDecode(line);
          yield PullProgress.fromJson(data);
        } catch (_) {}
      }
    } finally {
      client.close();
    }
  }

  Future<bool> deleteModel(String modelName) async {
    final client = http.Client();
    try {
      final request = http.Request('DELETE', Uri.parse('$baseUrl/api/delete'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'name': modelName});
      
      final response = await client.send(request);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }
}
