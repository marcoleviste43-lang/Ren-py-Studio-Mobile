import 'dart:convert';
import 'package:http/http.dart' as http;

import 'ai_provider.dart';

/// Talks to the Anthropic Messages API. This is the original `AiService`
/// request/response logic, unchanged, just relocated behind [AiProvider].
class ClaudeProvider implements AiProvider {
  ClaudeProvider(this.apiKey);

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';

  @override
  final String? apiKey;

  @override
  AiProviderId get id => AiProviderId.claude;

  @override
  String get displayName => 'Claude';

  @override
  String get apiKeyHint => 'sk-ant-...';

@override
bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  @override
  Future<String> send({
    required String apiKey,
    required String systemPrompt,
    required List<AiMessage> history,
    required String userMessage,
  }) async {
    final messages = [
      ...history.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 1500,
        'system': systemPrompt,
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Claude request failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['content'] as List;
    return content
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('\n');
  }
}
