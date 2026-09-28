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

  Stream<String> streamChat(String model, List<Map<String, dynamic>> messages, {double? temperature}) async* {
    final client = http.Client();
    final request = http.Request('POST', Uri.parse('$baseUrl/api/chat'));
    request.headers['Content-Type'] = 'application/json';
    final payload = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': true,
    };
    if (temperature != null) {
      payload['options'] = {'temperature': temperature};
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
          if (data['message'] != null && data['message']['content'] != null) {
            yield data['message']['content'] as String;
          }
        } catch (_) {
          // Ignore incomplete non-json line
        }
      }
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
