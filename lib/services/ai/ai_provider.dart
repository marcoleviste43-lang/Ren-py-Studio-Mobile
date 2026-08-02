/// A single turn in a conversation, provider-agnostic.
class AiMessage {
  final String role; // "user" | "assistant"
  final String content;
  const AiMessage(this.role, this.content);
}

/// Identifies which backend an [AiProvider] talks to. Stored in
/// SharedPreferences as its [name] so it survives across app restarts.
enum AiProviderId { claude, gemini }

/// Common interface every AI backend implements. `AiService` talks only to
/// this interface -- it never knows about Anthropic- or Gemini-specific
/// request/response shapes.
abstract class AiProvider {
  AiProviderId get id;

  /// Human-readable name shown in Settings (e.g. "Claude").
  String get displayName;

  /// Hint text shown in the API key entry field (e.g. "sk-ant-...").
  String get apiKeyHint;

  /// The API key currently in use, if any.
  String? get apiKey;

  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  /// Sends the full conversation history plus a new user message and
  /// returns the assistant's reply as plain text.
  ///
  /// [systemPrompt] is the shared, provider-independent instruction set.
  /// [history] is prior turns (not including [userMessage]).
  Future<String> send({
    required String apiKey,
    required String systemPrompt,
    required List<AiMessage> history,
    required String userMessage,
  });
}
