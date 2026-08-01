import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiChatMessage {
  final String role; // "user" | "assistant"
  final String content;
  AiChatMessage(this.role, this.content);
}

/// Talks to the Anthropic Messages API using an API key the user supplies
/// in Settings. Kept fully optional -- every other feature of the app
/// works with zero network access.
class AiService extends ChangeNotifier {
  static const _keyPref = 'renpy_studio.anthropic_api_key';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';

  String? apiKey;
  bool busy = false;
  final List<AiChatMessage> history = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    apiKey = prefs.getString(_keyPref);
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, key);
    notifyListeners();
  }

  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  static const _systemPrompt = '''
You are embedded inside Ren'Py Studio Mobile, an app for building Ren'Py
visual novels. Help the user write dialogue, scenes, character defines,
menus, and Python-in-Ren'Py logic. When you produce script, use valid
Ren'Py syntax (label blocks, `character "line"`, `menu:`, `jump`, `scene`,
`show ... at ...`, `define`). Keep explanations short; prioritize working
code the user can paste directly into their project.
''';

  /// Sends the running conversation plus a new user message, returns the
  /// assistant's reply and appends both turns to `history`.
  Future<String> ask(String userMessage, {String? projectContext}) async {
    if (!isConfigured) {
      throw StateError('No API key configured. Add one in AI Assistant settings.');
    }
    busy = true;
    notifyListeners();

    try {
      final messages = [
        ...history.map((m) => {'role': m.role, 'content': m.content}),
        {
          'role': 'user',
          'content': projectContext != null
              ? 'Project context:\n$projectContext\n\nRequest:\n$userMessage'
              : userMessage,
        },
      ];

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey!,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 1500,
          'system': _systemPrompt,
          'messages': messages,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('AI request failed (${response.statusCode}): '
            '${response.body}');
      }

      final data = jsonDecode(response.body);
      final content = data['content'] as List;
      final text = content
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'] as String)
          .join('\n');

      history.add(AiChatMessage('user', userMessage));
      history.add(AiChatMessage('assistant', text));
      return text;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void clearHistory() {
    history.clear();
    notifyListeners();
  }
}
