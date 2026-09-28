class PullProgress {
  final String status;
  final String? digest;
  final int total;
  final int completed;

  const PullProgress({
    required this.status,
    this.digest,
    this.total = 0,
    this.completed = 0,
  });

  factory PullProgress.fromJson(Map<String, dynamic> json) {
    return PullProgress(
      status: json['status'] as String? ?? 'unknown',
      digest: json['digest'] as String?,
      total: json['total'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
    );
  }

  double get percent => total > 0 ? completed / total : 0.0;
}
