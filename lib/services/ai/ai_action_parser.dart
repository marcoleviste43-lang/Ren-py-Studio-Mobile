import 'dart:convert';

import '../../models/renpy_project.dart';
import '../../models/script_file.dart';
import 'ai_action.dart';

/// Result of parsing a raw provider reply for an embedded action block.
class AiParsedReply {
  /// The reply text with the action block (if any) stripped out -- this
  /// is what gets shown in the chat transcript, so the user never sees
  /// raw JSON in the conversation.
  final String text;

  /// Zero or more script-edit actions the model proposed. Never applied
  /// automatically -- always routed through a confirmation UI first.
  final List<AiScriptEditAction> actions;

  const AiParsedReply({required this.text, required this.actions});
}

/// Extracts a fenced ` ```renpy-studio-action ` JSON block from a raw
/// provider reply (see `AiService`'s system prompt for the schema both
/// Claude and Gemini are given). This is deliberately a plain-text
/// convention rather than provider-native tool calling, so it works
/// identically for any `AiProvider` implementation without changing
/// that interface.
///
/// Tolerant by design: a model that replies with prose only, or with a
/// malformed/incomplete JSON block, still produces a usable
/// [AiParsedReply] with an empty `actions` list rather than throwing --
/// a parsing hiccup should never break the chat.
class AiActionParser {
  static final RegExp _blockPattern = RegExp(
    r'```renpy-studio-action\s*([\s\S]*?)```',
    multiLine: true,
  );

  static AiParsedReply parse(String rawReply, RenPyProject project) {
    final match = _blockPattern.firstMatch(rawReply);
    if (match == null) {
      return AiParsedReply(text: rawReply.trim(), actions: const []);
    }

    final cleanedText =
        (rawReply.substring(0, match.start) + rawReply.substring(match.end))
            .trim();
    final jsonText = match.group(1)?.trim() ?? '';

    if (jsonText.isEmpty) {
      return AiParsedReply(text: cleanedText, actions: const []);
    }

    List<dynamic> rawActions;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is List) {
        rawActions = decoded;
      } else if (decoded is Map && decoded['actions'] is List) {
        rawActions = decoded['actions'] as List;
      } else if (decoded is Map) {
        rawActions = [decoded];
      } else {
        rawActions = const [];
      }
    } catch (_) {
      // Malformed JSON from the model -- ignore the action block, keep
      // the prose reply so the conversation still makes sense.
      return AiParsedReply(text: cleanedText, actions: const []);
    }

    final actions = <AiScriptEditAction>[];
    for (final raw in rawActions) {
      final action = _tryParseOne(raw, project);
      if (action != null) actions.add(action);
    }

    return AiParsedReply(text: cleanedText, actions: actions);
  }

  static AiScriptEditAction? _tryParseOne(dynamic raw, RenPyProject project) {
    if (raw is! Map) return null;
    if (raw['action'] != 'edit_script') return null;

    final modeStr = raw['mode'];
    final content = raw['content'];
    if (modeStr is! String || content is! String || content.isEmpty) {
      return null;
    }

    AiEditMode? mode;
    for (final m in AiEditMode.values) {
      if (m.name == modeStr) {
        mode = m;
        break;
      }
    }
    if (mode == null) return null;

    final target = raw['target'];
    if (mode == AiEditMode.rewrite && (target is! String || target.isEmpty)) {
      // A rewrite without a find-target has nothing to anchor on --
      // drop it rather than guess.
      return null;
    }

    final scriptFileId = raw['scriptFileId'];
    final scriptFileNameHint = raw['scriptFileName'];

    ScriptFile? script;
    if (scriptFileId is String) {
      script = _findById(project, scriptFileId);
    }
    script ??=
        _findByName(project, scriptFileNameHint is String ? scriptFileNameHint : null);
    if (script == null) {
      // Can't resolve which file this targets -- drop it rather than
      // risk editing the wrong (or a nonexistent) file.
      return null;
    }

    return AiScriptEditAction(
      scriptFileId: script.id,
      scriptFileName: script.fileName,
      mode: mode,
      content: content,
      target: mode == AiEditMode.rewrite ? target as String : null,
      summary: raw['summary'] is String ? raw['summary'] as String : null,
    );
  }

  static ScriptFile? _findById(RenPyProject project, String id) {
    for (final s in project.scripts) {
      if (s.id == id) return s;
    }
    return null;
  }

  static ScriptFile? _findByName(RenPyProject project, String? name) {
    if (name == null || name.isEmpty) return null;
    for (final s in project.scripts) {
      if (s.fileName == name) return s;
    }
    return null;
  }
}
