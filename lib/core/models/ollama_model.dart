class OllamaModel {
  final String name;
  final String model;
  final int size;
  final String digest;
  final String modifiedAt;

  const OllamaModel({
    required this.name,
    required this.model,
    required this.size,
    required this.digest,
    required this.modifiedAt,
  });

  factory OllamaModel.fromJson(Map<String, dynamic> json) {
    return OllamaModel(
      name: json['name'] as String,
      model: json['model'] as String? ?? json['name'] as String,
      size: json['size'] as int? ?? 0,
      digest: json['digest'] as String? ?? '',
      modifiedAt: json['modified_at'] as String? ?? '',
    );
  }
}
