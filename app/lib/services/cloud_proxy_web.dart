// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

class CloudProxyAnswer {
  const CloudProxyAnswer({
    required this.text,
    required this.provider,
    required this.model,
    required this.latencyMs,
  });

  final String text;
  final String provider;
  final String model;
  final int latencyMs;
}

Future<CloudProxyAnswer> requestCloudFallback({
  required String task,
  required String input,
}) async {
  final clock = Stopwatch()..start();
  final request = await html.HttpRequest.request(
    '/api/analyze',
    method: 'POST',
    sendData: jsonEncode({'task': task, 'input': input}),
    requestHeaders: const {'Content-Type': 'application/json'},
  ).timeout(const Duration(seconds: 32));
  if (request.status != 200) {
    throw StateError('Cloud interpretation is unavailable. Your local review remains usable.');
  }
  final response = jsonDecode(request.responseText ?? '') as Map<String, dynamic>;
  final text = response['text'];
  if (text is! String || text.trim().isEmpty) {
    throw StateError('Cloud interpretation returned no usable result.');
  }
  clock.stop();
  return CloudProxyAnswer(
    text: text,
    provider: response['provider'] as String? ?? 'Cloud fallback',
    model: response['model'] as String? ?? 'configured model',
    latencyMs: clock.elapsedMilliseconds,
  );
}
