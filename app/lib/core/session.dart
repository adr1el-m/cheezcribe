class StudioSession {
  const StudioSession(
      {required this.id,
      required this.task,
      required this.input,
      required this.createdAt,
      this.output,
      this.model,
      this.latencyMs});
  final String id;
  final String task;
  final String input;
  final DateTime createdAt;
  final String? output;
  final String? model;
  final int? latencyMs;
  bool get completed => output != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'task': task,
        'input': input,
        'createdAt': createdAt.toIso8601String(),
        'output': output,
        'model': model,
        'latencyMs': latencyMs,
      };
  factory StudioSession.fromJson(Map<String, dynamic> json) => StudioSession(
        id: json['id'] as String,
        task: json['task'] as String,
        input: json['input'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        output: json['output'] as String?,
        model: json['model'] as String?,
        latencyMs: json['latencyMs'] as int?,
      );
}
