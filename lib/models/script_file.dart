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
  String compile() {
    if (rawOverride != null) return rawOverride!;

    final buffer = StringBuffer();
    int indent = 1; // most content sits inside a label block
    for (final line in lines) {
      if (line.kind == DialogueKind.label) {
        buffer.writeln(line.toRenPy());
        indent = 1;
        continue;
      }
      final pad = '    ' * indent;
      final rendered = line.toRenPy();
      // indent every sub-line for multi-line menu blocks
      final indented =
          rendered.split('\n').map((l) => l.isEmpty ? l : '$pad$l').join('\n');
      buffer.writeln(indented);
    }
    return buffer.toString();
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
