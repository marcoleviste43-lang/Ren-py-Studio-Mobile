/// The kind of a single structured line in the dialogue editor.
enum DialogueKind {
  say, // character_var "line"
  narration, // "line" (no speaker)
  menuChoice, // menu option -> jump/label
  sceneShow, // scene / show statement
  label, // label some_label:
  jump, // jump some_label
  comment, // # comment
}

class DialogueLine {
  String id;
  DialogueKind kind;
  String? speakerVarName; // null for narration/system lines
  String text; // dialogue text, image tag, label name, etc.
  List<MenuOption> menuOptions; // populated only when kind == menuChoice
  String? attribute; // e.g. "happy" mood/expression tag for `show` lines

  DialogueLine({
    required this.id,
    required this.kind,
    this.speakerVarName,
    this.text = '',
    List<MenuOption>? menuOptions,
    this.attribute,
  }) : menuOptions = menuOptions ?? [];

  /// Renders this single structured line as valid Ren'Py script text
  /// (indentation is applied by the caller/exporter, not here).
  String toRenPy() {
    switch (kind) {
      case DialogueKind.say:
        final who = speakerVarName ?? '';
        return '$who "${_escape(text)}"';
      case DialogueKind.narration:
        return '"${_escape(text)}"';
      case DialogueKind.sceneShow:
        return text; // caller writes raw e.g. "show eileen happy at left"
      case DialogueKind.label:
        return 'label $text:';
      case DialogueKind.jump:
        return 'jump $text';
      case DialogueKind.comment:
        return '# $text';
      case DialogueKind.menuChoice:
        final buffer = StringBuffer('menu:\n');
        for (final opt in menuOptions) {
          buffer.writeln('    "${_escape(opt.label)}":');
          buffer.writeln('        jump ${opt.jumpTarget}');
        }
        return buffer.toString().trimRight();
    }
  }

  static String _escape(String s) => s.replaceAll('"', '\\"');

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'speakerVarName': speakerVarName,
        'text': text,
        'attribute': attribute,
        'menuOptions': menuOptions.map((m) => m.toJson()).toList(),
      };

  factory DialogueLine.fromJson(Map<String, dynamic> json) => DialogueLine(
        id: json['id'],
        kind: DialogueKind.values.firstWhere((k) => k.name == json['kind']),
        speakerVarName: json['speakerVarName'],
        text: json['text'] ?? '',
        attribute: json['attribute'],
        menuOptions: (json['menuOptions'] as List? ?? [])
            .map((m) => MenuOption.fromJson(m))
            .toList(),
      );
}

class MenuOption {
  String label;
  String jumpTarget;
  MenuOption({required this.label, required this.jumpTarget});

  Map<String, dynamic> toJson() => {'label': label, 'jumpTarget': jumpTarget};
  factory MenuOption.fromJson(Map<String, dynamic> json) =>
      MenuOption(label: json['label'], jumpTarget: json['jumpTarget']);
}
