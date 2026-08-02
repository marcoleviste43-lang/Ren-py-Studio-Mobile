import 'dart:convert';
import 'package:http/http.dart' as http;

import 'ai_provider.dart';

/// Talks to the Google Gemini `generateContent` REST API.
class GeminiProvider implements AiProvider {
  GeminiProvider(this.apiKey);

  static const _model = 'gemini-2.5-flash';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  @override
  final String? apiKey;

  @override
  AiProviderId get id => AiProviderId.gemini;

  @override
  String get displayName => 'Gemini';

  @override
  String get apiKeyHint => 'AIza...';

  @override
  Future<String> send({
    required String apiKey,
    required String systemPrompt,
    required List<AiMessage> history,
    required String userMessage,
  }) async {
    // Gemini uses "user" / "model" roles (not "assistant"), and nests text
    // under `content.parts[].text` instead of a flat string.
    final contents = [
      ...history.map((m) => {
            'role': m.role == 'assistant' ? 'model' : 'user',
            'parts': [
              {'text': m.content}
            ],
          }),
      {
        'role': 'user',
        'parts': [
          {'text': userMessage}
        ],
      },
    ];

    final uri = Uri.parse('$_baseUrl/$_model:generateContent?key=$apiKey');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': contents,
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ],
        },
        'generationConfig': {'maxOutputTokens': 1500},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini request failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      // Most commonly a safety block -- promptFeedback carries the reason.
      final blockReason = data['promptFeedback']?['blockReason'];
      throw Exception(blockReason != null
          ? 'Gemini blocked the request ($blockReason).'
          : 'Gemini returned no candidates.');
    }

    final parts = candidates.first['content']?['parts'] as List? ?? const [];
    return parts
        .where((p) => p['text'] != null)
        .map((p) => p['text'] as String)
        .join('\n');
  }
}
