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

  /// Throws when the daemon is unreachable or answers with an error, so callers
  /// can tell "no models installed" apart from "Ollama is not running".
  Future<List<OllamaModel>> listModels() async {
    final response = await http.get(Uri.parse('$baseUrl/api/tags'));
    if (response.statusCode != 200) {
      throw HttpException('Ollama returned HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    return (data['models'] as List).map((e) => OllamaModel.fromJson(e)).toList();
  }

  /// Whether [modelName] is currently held in memory. Null when the daemon did
  /// not answer in time; callers should then assume nothing either way.
  Future<bool?> isModelLoaded(String modelName) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/ps')).timeout(const Duration(milliseconds: 500));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final models = (data['models'] as List?) ?? const [];
      return models.any((m) => m is Map && (m['name'] == modelName || m['model'] == modelName));
    } catch (_) {
      return null;
    }
  }

  /// Context window [modelName] is loaded with right now, or null if it is not
  /// loaded or the daemon does not report it. This is how the app learns the
  /// daemon's own default, which no other endpoint exposes.
  Future<int?> loadedContextLength(String modelName) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/ps')).timeout(const Duration(milliseconds: 500));
      if (response.statusCode != 200) return null;
      final models = (jsonDecode(response.body)['models'] as List?) ?? const [];
      for (final m in models) {
        if (m is Map && (m['name'] == modelName || m['model'] == modelName)) {
          final length = m['context_length'];
          return length is int && length > 0 ? length : null;
        }
      }
    } catch (_) {
      // Not reachable in time: the caller keeps its assumption.
    }
    return null;
  }

  Stream<String> streamChat(
    String model,
    List<Map<String, dynamic>> messages, {
    double? temperature,
    int? numCtx,
    int? numThread,
    bool? think,
    List<Map<String, dynamic>>? tools,
    void Function(Map<String, dynamic> toolCall)? onToolCall,
    void Function(Map<String, dynamic> doneMetrics)? onDoneMetrics,
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
    if (think != null) {
      payload['think'] = think;
    }
    final options = _buildOptions(temperature: temperature, numCtx: numCtx, numThread: numThread);
    if (options.isNotEmpty) {
      payload['options'] = options;
    }
    request.body = jsonEncode(payload);

    // Reasoning arrives in its own `thinking` field when the daemon separates it.
    // It is folded back into <think> tags so one parser handles both styles.
    bool thinkOpen = false;

    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw HttpException('Ollama returned HTTP ${response.statusCode}');
      }

      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        try {
          final data = jsonDecode(line);
          if (data is Map<String, dynamic>) {
            if (data['done'] == true) {
              onDoneMetrics?.call(data);
            }

            final msg = data['message'];
            if (msg != null && msg is Map<String, dynamic>) {
              final thinking = msg['thinking'];
              if (thinking is String && thinking.isNotEmpty) {
                if (!thinkOpen) {
                  thinkOpen = true;
                  yield '<think>';
                }
                yield thinking;
              }

              // Check for native tool calls or json tool call in content
              final toolCall = _extractToolCall(msg);
              if (toolCall != null) {
                onToolCall?.call(toolCall);
              }

              if (msg['content'] != null) {
                final content = msg['content'] as String;
                if (content.isNotEmpty && toolCall == null) {
                  if (thinkOpen) {
                    thinkOpen = false;
                    yield '</think>';
                  }
                  yield content;
                }
              }
            }
          }
        } catch (_) {
          // Ignore incomplete non-json line
        }
      }
      if (thinkOpen) {
        yield '</think>';
      }
    } finally {
      client.close();
    }
  }

  /// Runner options shared by every chat request. `num_ctx` and `num_thread`
  /// are load-time options: a request that sends different values than the
  /// previous one makes Ollama reload the model, so side requests (titles,
  /// summaries) must go through here with the same values as the chat itself.
  static Map<String, dynamic> _buildOptions({double? temperature, int? numCtx, int? numThread}) {
    final options = <String, dynamic>{};
    if (temperature != null) {
      options['temperature'] = temperature;
    }
    if (numCtx != null) {
      options['num_ctx'] = numCtx;
    }
    if (numThread != null) {
      options['num_thread'] = numThread;
    } else {
      // Keep at least 1 core free for OS / Wayland compositor / UI to prevent desktop input freezing
      final procs = Platform.numberOfProcessors;
      if (procs > 4) {
        options['num_thread'] = 4;
      } else if (procs > 1) {
        options['num_thread'] = procs - 1;
      }
    }
    return options;
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
    bool? think,
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
      if (think != null) {
        payload['think'] = think;
      }
      final options = _buildOptions(temperature: temperature, numCtx: numCtx);
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
