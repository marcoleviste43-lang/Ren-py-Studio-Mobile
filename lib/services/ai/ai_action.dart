/// How an [AiScriptEditAction] should be applied to a script file's
/// text. All three modes operate on the file's raw text (the same
/// text `ScriptFile.compile()` would produce, or `rawOverride` if the
/// file is already in Raw Mode) -- there is no structured-block variant,
/// so applying any of these always leaves the target file in Raw Mode
/// afterward, exactly as if the user had hand-edited it.
enum AiEditMode {
  /// Add `content` to the end of the file's current text.
  append,

  /// Replace the entire file's text with `content`.
  replace,

  /// Find the exact text `target` in the file's current text and
  /// replace that one occurrence with `content`. Used for small,
  /// surgical rewrites (e.g. "rewrite this one line") without touching
  /// the rest of the file.
  rewrite,
}

/// A single AI-proposed edit to one script file's raw `.rpy` text.
///
/// This is a pure data holder -- it is never applied automatically.
/// `AiActionParser` produces it from a provider's reply, the chat UI
/// shows it via a preview card, and only `AiActionExecutor.apply()`
/// (triggered by an explicit user confirmation) ever mutates a project
/// with it.
class AiScriptEditAction {
  /// The `ScriptFile.id` this action targets, resolved at parse time
  /// against the project the request was made about.
  final String scriptFileId;

  /// The target file's name at parse time, kept alongside the id purely
  /// for display (and as a fallback lookup key if a file gets renamed
  /// between proposal and confirmation).
  final String scriptFileName;

  final AiEditMode mode;

  /// The new text to append/replace/substitute in, verbatim -- never
  /// reformatted.
  final String content;

  /// Required and only meaningful when [mode] is [AiEditMode.rewrite]:
  /// the exact existing text to find and replace.
  final String? target;

  /// Optional short, human-readable description of the change, shown on
  /// the preview card if the model provided one.
  final String? summary;

  const AiScriptEditAction({
    required this.scriptFileId,
    required this.scriptFileName,
    required this.mode,
    required this.content,
    this.target,
    this.summary,
  });
}
