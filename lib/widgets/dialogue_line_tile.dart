import 'package:flutter/material.dart';
import '../models/dialogue_line.dart';
import '../models/character.dart';

class DialogueLineTile extends StatelessWidget {
  final DialogueLine line;
  final List<Character> characters;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const DialogueLineTile({
    super.key,
    required this.line,
    required this.characters,
    required this.onChanged,
    required this.onDelete,
  });

  IconData get _icon {
    switch (line.kind) {
      case DialogueKind.say:
        return Icons.chat_bubble_outline;
      case DialogueKind.narration:
        return Icons.short_text;
      case DialogueKind.sceneShow:
        return Icons.landscape_outlined;
      case DialogueKind.label:
        return Icons.label_outline;
      case DialogueKind.jump:
        return Icons.arrow_forward;
      case DialogueKind.comment:
        return Icons.comment_outlined;
      case DialogueKind.menuChoice:
        return Icons.list_alt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The whole tile is draggable via long-press (default behavior
            // of ReorderableListView.builder); this icon just signals kind.
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 4),
              child: Icon(_icon, size: 18, color: Colors.white54),
            ),
            Expanded(child: _buildEditor(context)),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    switch (line.kind) {
      case DialogueKind.say:
        return _SayEditor(line: line, characters: characters, onChanged: onChanged);
      case DialogueKind.narration:
      case DialogueKind.sceneShow:
      case DialogueKind.label:
      case DialogueKind.jump:
      case DialogueKind.comment:
        return _SimpleTextEditor(line: line, onChanged: onChanged);
      case DialogueKind.menuChoice:
        return _MenuEditor(line: line, onChanged: onChanged);
    }
  }
}

class _SayEditor extends StatelessWidget {
  final DialogueLine line;
  final List<Character> characters;
  final VoidCallback onChanged;
  const _SayEditor(
      {required this.line, required this.characters, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          value: characters.any((c) => c.varName == line.speakerVarName)
              ? line.speakerVarName
              : null,
          hint: const Text('Speaker'),
          isDense: true,
          items: characters
              .map((c) => DropdownMenuItem(
                  value: c.varName,
                  child: Text('${c.displayName} (${c.varName})')))
              .toList(),
          onChanged: (v) {
            line.speakerVarName = v;
            onChanged();
          },
        ),
        TextFormField(
          initialValue: line.text,
          maxLines: null,
          decoration: const InputDecoration(
              isDense: true, hintText: 'Dialogue line…'),
          onChanged: (v) {
            line.text = v;
            onChanged();
          },
        ),
      ],
    );
  }
}

class _SimpleTextEditor extends StatelessWidget {
  final DialogueLine line;
  final VoidCallback onChanged;
  const _SimpleTextEditor({required this.line, required this.onChanged});

  String get _hint {
    switch (line.kind) {
      case DialogueKind.narration:
        return 'Narration text…';
      case DialogueKind.sceneShow:
        return 'e.g. show eileen happy at left';
      case DialogueKind.label:
        return 'label_name';
      case DialogueKind.jump:
        return 'target_label';
      case DialogueKind.comment:
        return 'Comment text';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line.kind.name.toUpperCase(),
            style: const TextStyle(
                fontSize: 10, letterSpacing: 1, color: Colors.white38)),
        TextFormField(
          initialValue: line.text,
          maxLines: null,
          decoration: InputDecoration(isDense: true, hintText: _hint),
          onChanged: (v) {
            line.text = v;
            onChanged();
          },
        ),
      ],
    );
  }
}

class _MenuEditor extends StatefulWidget {
  final DialogueLine line;
  final VoidCallback onChanged;
  const _MenuEditor({required this.line, required this.onChanged});

  @override
  State<_MenuEditor> createState() => _MenuEditorState();
}

class _MenuEditorState extends State<_MenuEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MENU',
            style: TextStyle(
                fontSize: 10, letterSpacing: 1, color: Colors.white38)),
        ...widget.line.menuOptions.asMap().entries.map((entry) {
          final opt = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: opt.label,
                    decoration: const InputDecoration(
                        isDense: true, hintText: 'Choice text'),
                    onChanged: (v) {
                      opt.label = v;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: opt.jumpTarget,
                    decoration: const InputDecoration(
                        isDense: true, hintText: 'jump target'),
                    onChanged: (v) {
                      opt.jumpTarget = v;
                      widget.onChanged();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () {
                    setState(() => widget.line.menuOptions.remove(opt));
                    widget.onChanged();
                  },
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() => widget.line.menuOptions.add(
                MenuOption(label: 'New choice', jumpTarget: 'label_target')));
            widget.onChanged();
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add choice'),
        ),
      ],
    );
  }
}
