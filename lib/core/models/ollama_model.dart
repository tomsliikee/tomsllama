class OllamaModel {
  final String name;
  final String model;
  final int size;
  final String digest;
  final String modifiedAt;

  /// Capability tags reported by Ollama (`completion`, `tools`, `thinking`, ...).
  /// Empty on daemons too old to report them, which means "unknown", not "none".
  final List<String> capabilities;

  /// Largest context the model was trained for, if the daemon reports it.
  final int? contextLength;

  const OllamaModel({
    required this.name,
    required this.model,
    required this.size,
    required this.digest,
    required this.modifiedAt,
    this.capabilities = const [],
    this.contextLength,
  });

  bool? get supportsThinking => capabilities.isEmpty ? null : capabilities.contains('thinking');
  bool? get supportsTools => capabilities.isEmpty ? null : capabilities.contains('tools');

  factory OllamaModel.fromJson(Map<String, dynamic> json) {
    return OllamaModel(
      name: json['name'] as String,
      model: json['model'] as String? ?? json['name'] as String,
      size: json['size'] as int? ?? 0,
      digest: json['digest'] as String? ?? '',
      modifiedAt: json['modified_at'] as String? ?? '',
      capabilities: (json['capabilities'] as List?)?.whereType<String>().toList() ?? const [],
      contextLength: (json['details'] as Map?)?['context_length'] as int?,
    );
  }
}
