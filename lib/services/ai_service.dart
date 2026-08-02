import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/renpy_project.dart';
import 'ai/ai_action.dart';
import 'ai/ai_action_parser.dart';
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

  /// Script-edit actions proposed by the most recent [ask] call that
  /// haven't yet been applied or discarded. The chat UI renders these as
  /// preview cards; `dismissAction`/`clearPendingActions` remove them
  /// once the user decides. Never applied without going through that
  /// confirmation step.
  List<AiScriptEditAction> pendingActions = [];

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
`show ... at ...`, `define`). Keep explanations short.

You are also able to directly propose an edit to one of the user's
existing script files, instead of only showing code in chat. Do this
whenever the user is asking you to add to, change, or fix a script file
that already exists (its id and file name will be listed under "Script
files" in the project context below) -- not for general questions or
brand-new standalone snippets they didn't ask you to insert anywhere.

To propose an edit, after your normal reply, append exactly one fenced
code block using the language tag `renpy-studio-action` containing a
single JSON object (or `{"actions": [...]}` for more than one file) with
this shape:

```renpy-studio-action
{
  "action": "edit_script",
  "scriptFileId": "<the id of the target file from the context below>",
  "mode": "append" | "replace" | "rewrite",
  "content": "<the new Ren'Py text, valid syntax, exact formatting>",
  "target": "<only when mode is \"rewrite\": the exact existing text to find and replace>",
  "summary": "<a short one-line description of the change, e.g. 'Add rival's intro scene'>"
}
```

Rules for this block:
- Only include it when you are actually proposing a file edit; otherwise
  omit it entirely and just reply normally.
- `mode: "append"` adds `content` to the end of the file.
- `mode: "replace"` replaces the file's entire contents with `content`
  -- use this only when the user wants the whole file rewritten.
- `mode: "rewrite"` finds the exact text in `target` and replaces just
  that occurrence with `content` -- use this for small, targeted edits
  so the rest of the file is left untouched. `target` must match the
  file's current text exactly, or the edit will fail.
- `scriptFileId` must be one of the ids listed in the project context.
  Never invent one.
- `content` must be valid, directly-usable Ren'Py script text.
- You never apply this edit yourself -- the app always shows the user a
  preview and requires them to confirm before anything changes.
''';

  /// Sends the running conversation plus a new user message through the
  /// currently-selected provider, appends both turns to `history`, and
  /// updates [pendingActions] with any script edits the model proposed.
  /// The reply text shown in `history`/the chat has any action JSON
  /// block stripped out -- callers read [pendingActions] separately to
  /// render confirmation UI.
  Future<void> ask(String userMessage, {required RenPyProject project}) async {
    final provider = _activeProvider;
    if (!provider.isConfigured) {
      throw StateError(
          'No API key configured for ${provider.displayName}. Add one in AI Assistant settings.');
    }
    busy = true;
    notifyListeners();

    try {
      final context = _buildProjectContext(project);
      final fullMessage = 'Project context:\n$context\n\nRequest:\n$userMessage';

      final rawReply = await provider.send(
        apiKey: provider.apiKey!,
        systemPrompt: _systemPrompt,
        history: history,
        userMessage: fullMessage,
      );

      final parsed = AiActionParser.parse(rawReply, project);

      history.add(AiMessage('user', userMessage));
      history.add(AiMessage('assistant', parsed.text));
      pendingActions = parsed.actions;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Builds the project context sent with every request: characters and
  /// script files (with ids), so the model can both answer questions
  /// about the project and reference a specific file by id when
  /// proposing an edit action.
  String _buildProjectContext(RenPyProject project) {
    final chars = project.characters
        .map((c) => '${c.varName}="${c.displayName}"')
        .join(', ');
    final scripts = project.scripts
        .map((s) =>
            '- id=${s.id} fileName=${s.fileName}${s.isRawMode ? ' [RAW MODE]' : ''}')
        .join('\n');
    return 'Project "${project.name}".\n'
        'Characters: ${chars.isEmpty ? '(none)' : chars}.\n'
        'Script files:\n${scripts.isEmpty ? '(none yet)' : scripts}';
  }

  /// Removes [action] from [pendingActions] -- called once the user
  /// applies or discards it.
  void dismissAction(AiScriptEditAction action) {
    pendingActions = pendingActions.where((a) => a != action).toList();
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    pendingActions = [];
    notifyListeners();
  }
}
