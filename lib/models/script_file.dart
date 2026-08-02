import 'dialogue_line.dart';

/// Represents one .rpy file inside game/. Keeps both:
///  - `lines`: structured content used by the visual dialogue editor
///  - `rawOverride`: if the user edited raw text directly, that text wins
class ScriptFile {
  String id;
  String fileName; // e.g. "script.rpy" or "chapter1.rpy"
  List<DialogueLine> lines;
  String? rawOverride;

  ScriptFile({
    required this.id,
    required this.fileName,
    List<DialogueLine>? lines,
    this.rawOverride,
  }) : lines = lines ?? [];

  /// Compiles this file to final Ren'Py source text.
  ///
  /// Ren'Py labels don't stop at the end of their own content: if a
  /// label's last statement isn't a `jump` (or a `menu:` block, whose
  /// every branch already ends in its own `jump` by construction --
  /// see `MenuOption`), Ren'Py keeps executing straight into whatever
  /// label happens to come next. That's a silent wrong-path bug, not a
  /// syntax error, so it won't surface until someone actually plays
  /// that branch. To make it impossible, every label whose content
  /// doesn't already guarantee an explicit hand-off gets an automatic
  /// `return` appended.
  String compile() {
    if (rawOverride != null) return rawOverride!;

    final buffer = StringBuffer();
    List<DialogueLine>? currentLabelBody;

    void flushLabel() {
      final body = currentLabelBody;
      if (body == null) return;
      for (final line in body) {
        _writeIndented(buffer, line);
      }
      if (_needsAutoReturn(body)) {
        buffer.writeln('    return');
      }
      currentLabelBody = null;
    }

    for (final line in lines) {
      if (line.kind == DialogueKind.label) {
        flushLabel(); // close out the previous label, if any, first
        buffer.writeln(line.toRenPy());
        currentLabelBody = [];
      } else if (currentLabelBody != null) {
        currentLabelBody!.add(line);
      } else {
        // Content before any label -- unchanged from prior behavior;
        // there's no label here yet for it to fall through from.
        _writeIndented(buffer, line);
      }
    }
    flushLabel();

    return buffer.toString();
  }

  static void _writeIndented(StringBuffer buffer, DialogueLine line,
      [int indent = 1]) {
    final pad = '    ' * indent;
    final rendered = line.toRenPy();
    // indent every sub-line for multi-line menu blocks
    final indented =
        rendered.split('\n').map((l) => l.isEmpty ? l : '$pad$l').join('\n');
    buffer.writeln(indented);
  }

  /// True if [body]'s last non-comment line doesn't already guarantee
  /// this label hands control somewhere explicit: a `jump`, or a
  /// `menu:` block where every option genuinely has a jump target (see
  /// [_menuAlwaysJumps] -- this is checked against the actual option
  /// data, not assumed from the line's `DialogueKind` alone). An empty
  /// or comment-only body also needs the safety net -- it would
  /// otherwise fall straight into the next label with nothing between.
  static bool _needsAutoReturn(List<DialogueLine> body) {
    DialogueLine? lastMeaningful;
    for (final line in body.reversed) {
      if (line.kind == DialogueKind.comment) continue;
      lastMeaningful = line;
      break;
    }
    if (lastMeaningful == null) return true;
    if (lastMeaningful.kind == DialogueKind.jump) return false;
    if (lastMeaningful.kind == DialogueKind.menuChoice) {
      return !_menuAlwaysJumps(lastMeaningful);
    }
    return true;
  }

  /// `DialogueLine.toRenPy()` currently renders a `jump <target>` line
  /// for every menu option -- but that's a property of the *renderer*,
  /// not something the type system enforces. `MenuOption.jumpTarget` is
  /// non-null but not guaranteed non-empty (the dialogue editor lets it
  /// be typed/cleared freely), and a future change to `toRenPy()` could
  /// add an inline-text option kind without anyone updating this check.
  /// So this inspects the actual option data on every call rather than
  /// trusting the line's `DialogueKind` as a permanent guarantee.
  static bool _menuAlwaysJumps(DialogueLine menu) {
    if (menu.menuOptions.isEmpty) return false; // no branches at all
    return menu.menuOptions.every((opt) => opt.jumpTarget.trim().isNotEmpty);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'lines': lines.map((l) => l.toJson()).toList(),
        'rawOverride': rawOverride,
      };

  factory ScriptFile.fromJson(Map<String, dynamic> json) => ScriptFile(
        id: json['id'],
        fileName: json['fileName'],
        lines: (json['lines'] as List? ?? [])
            .map((l) => DialogueLine.fromJson(l))
            .toList(),
        rawOverride: json['rawOverride'],
      );
}
