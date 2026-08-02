import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai/ai_provider.dart';
import 'ai/claude_provider.dart';
import 'ai/gemini_provider.dart';

/// Kept for backwards compatibility with existing UI code -- this is just
/// an alias for the provider-agnostic message type.
typedef AiChatMessage = AiMessage;

/// Controller for the AI assistant. Holds the selected provider, the API
/// keys for every provider, and the conversation history. Contains no
/// provider-specific request/response code -- that lives in
/// `services/ai/*_provider.dart`.
class AiService extends ChangeNotifier {
  static const _providerPref = 'renpy_studio.ai_provider';
  static const _claudeKeyPref = 'renpy_studio.anthropic_api_key';
  static const _geminiKeyPref = 'renpy_studio.gemini_api_key';

  AiProviderId _selectedProvider = AiProviderId.claude;
  String? _claudeApiKey;
  String? _geminiApiKey;

  bool busy = false;
  final List<AiMessage> history = [];

  AiProviderId get selectedProvider => _selectedProvider;

  /// The currently-active provider instance, wired up with its own key.
  AiProvider get _activeProvider {
    switch (_selectedProvider) {
      case AiProviderId.claude:
        return ClaudeProvider(_claudeApiKey);
      case AiProviderId.gemini:
        return GeminiProvider(_geminiApiKey);
    }
  }

  /// All providers, for building a Settings picker UI.
  List<AiProvider> get availableProviders => [
        ClaudeProvider(_claudeApiKey),
        GeminiProvider(_geminiApiKey),
      ];

  String? get apiKey => _activeProvider.apiKey;

  bool get isConfigured => _activeProvider.isConfigured;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final storedProvider = prefs.getString(_providerPref);
    _selectedProvider = AiProviderId.values.firstWhere(
      (p) => p.name == storedProvider,
      orElse: () => AiProviderId.claude,
    );
    _claudeApiKey = prefs.getString(_claudeKeyPref);
    _geminiApiKey = prefs.getString(_geminiKeyPref);
    notifyListeners();
  }

  Future<void> setProvider(AiProviderId providerId) async {
    _selectedProvider = providerId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerPref, providerId.name);
    notifyListeners();
  }

  /// Sets the API key for whichever provider is currently selected.
  /// Kept for backwards compatibility with the existing Settings dialog.
  Future<void> setApiKey(String key) => setApiKeyFor(_selectedProvider, key);

  Future<void> setApiKeyFor(AiProviderId providerId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    switch (providerId) {
      case AiProviderId.claude:
        _claudeApiKey = key;
        await prefs.setString(_claudeKeyPref, key);
        break;
      case AiProviderId.gemini:
        _geminiApiKey = key;
        await prefs.setString(_geminiKeyPref, key);
        break;
    }
    notifyListeners();
  }

  static const _systemPrompt = '''
You are embedded inside Ren'Py Studio Mobile, an app for building Ren'Py
visual novels. Help the user write dialogue, scenes, character defines,
menus, and Python-in-Ren'Py logic. When you produce script, use valid
Ren'Py syntax (label blocks, `character "line"`, `menu:`, `jump`, `scene`,
`show ... at ...`, `define`). Keep explanations short; prioritize working
code the user can paste directly into their project.
''';

  /// Sends the running conversation plus a new user message through the
  /// currently-selected provider, returns the assistant's reply, and
  /// appends both turns to `history`.
  Future<String> ask(String userMessage, {String? projectContext}) async {
    final provider = _activeProvider;
    if (!provider.isConfigured) {
      throw StateError(
          'No API key configured for ${provider.displayName}. Add one in AI Assistant settings.');
    }
    busy = true;
    notifyListeners();

    try {
      final fullMessage = projectContext != null
          ? 'Project context:\n$projectContext\n\nRequest:\n$userMessage'
          : userMessage;

      final text = await provider.send(
        apiKey: provider.apiKey!,
        systemPrompt: _systemPrompt,
        history: history,
        userMessage: fullMessage,
      );

      history.add(AiMessage('user', userMessage));
      history.add(AiMessage('assistant', text));
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
