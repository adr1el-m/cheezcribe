import 'dart:convert';
import 'dart:io';

import 'fusion_models.dart';

class LlmMessage {
  const LlmMessage(this.role, this.content);
  const LlmMessage.system(this.content) : role = 'system';
  const LlmMessage.user(this.content) : role = 'user';
  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class LlmResult {
  const LlmResult({
    required this.text,
    required this.model,
    this.citations = const [],
  });
  final String text;
  final String model;

  /// URLs the provider's search actually returned. Empty without web search.
  final List<RawCitation> citations;
}

class LlmException implements Exception {
  const LlmException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Provider-neutral chat completion used by the fusion services.
abstract class LlmClient {
  bool get ready;
  String get model;
  Future<LlmResult> complete(
    List<LlmMessage> messages, {
    bool webSearch = false,
    int maxResults = 6,
    double temperature = .2,
  });
}

/// OpenRouter chat completions. Web search uses OpenRouter's `web` plugin,
/// whose `url_citation` annotations are the only source of URLs.
class OpenRouterClient implements LlmClient {
  OpenRouterClient({String apiKey = '', String model = defaultModel})
      : _apiKey = apiKey.trim(),
        _model = model.trim().isEmpty ? defaultModel : model.trim();

  static const defaultModel = 'google/gemini-2.5-flash';
  static final _endpoint =
      Uri.parse('https://openrouter.ai/api/v1/chat/completions');

  String _apiKey;
  String _model;

  @override
  bool get ready => _apiKey.isNotEmpty;
  @override
  String get model => _model;
  String get apiKey => _apiKey;

  void configure({String? apiKey, String? model}) {
    if (apiKey != null) _apiKey = apiKey.trim();
    if (model != null && model.trim().isNotEmpty) _model = model.trim();
  }

  @override
  Future<LlmResult> complete(
    List<LlmMessage> messages, {
    bool webSearch = false,
    int maxResults = 6,
    double temperature = .2,
  }) async {
    if (!ready) throw const LlmException('No OpenRouter key configured.');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(_endpoint);
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey')
        ..set('X-Title', 'Paperazzi');
      request.add(utf8.encode(jsonEncode({
        'model': _model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': temperature,
        if (webSearch)
          'plugins': [
            {'id': 'web', 'max_results': maxResults}
          ],
      })));
      final response =
          await request.close().timeout(const Duration(seconds: 120));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw LlmException(_errorMessage(body, response.statusCode));
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const LlmException('The model returned no answer.');
      }
      final message =
          Map<String, dynamic>.from((choices.first as Map)['message'] as Map);
      final citations = <RawCitation>[];
      for (final annotation in (message['annotations'] as List? ?? const [])) {
        if (annotation is! Map || annotation['type'] != 'url_citation') {
          continue;
        }
        final cite = annotation['url_citation'];
        if (cite is! Map || cite['url'] is! String) continue;
        citations.add(RawCitation(
          url: cite['url'] as String,
          title: (cite['title'] as String?) ?? '',
          content: (cite['content'] as String?) ?? '',
        ));
      }
      return LlmResult(
        text: (message['content'] as String?) ?? '',
        model: (decoded['model'] as String?) ?? _model,
        citations: citations,
      );
    } on SocketException {
      throw const LlmException('No network connection.');
    } finally {
      client.close();
    }
  }

  static String _errorMessage(String body, int status) {
    try {
      final error = (jsonDecode(body) as Map)['error'];
      if (error is Map && error['message'] is String) {
        return 'OpenRouter $status: ${error['message']}';
      }
    } catch (_) {}
    return 'OpenRouter request failed ($status).';
  }
}

/// Extracts the first JSON object from model text, tolerating code fences.
Map<String, dynamic>? parseJsonObject(String text) {
  final first = text.indexOf('{');
  final last = text.lastIndexOf('}');
  if (first < 0 || last <= first) return null;
  try {
    final value = jsonDecode(text.substring(first, last + 1));
    return value is Map ? Map<String, dynamic>.from(value) : null;
  } catch (_) {
    return null;
  }
}
