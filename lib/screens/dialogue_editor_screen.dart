import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/renpy_project.dart';
import '../models/script_file.dart';
import '../models/dialogue_line.dart';
import '../models/character.dart';
import '../services/project_service.dart';
import '../widgets/dialogue_line_tile.dart';
import '../widgets/character_chip_bar.dart';

const _uuid = Uuid();

/// Visual, block-based dialogue editor. Each ScriptFile is a tab; each
/// tab is a reorderable list of DialogueLine blocks that compile to
/// valid Ren'Py syntax. A "View Raw" toggle shows the compiled output.
class DialogueEditorScreen extends StatefulWidget {
  final RenPyProject project;
  const DialogueEditorScreen({super.key, required this.project});

  @override
  State<DialogueEditorScreen> createState() => _DialogueEditorScreenState();
}

class _DialogueEditorScreenState extends State<DialogueEditorScreen> {
  int _scriptIndex = 0;
  bool _showRaw = false;

  ScriptFile get _script => widget.project.scripts[_scriptIndex];

  void _persist() {
    context.read<ProjectService>().updateProject(widget.project);
    setState(() {});
  }

  Future<void> _addScriptFile() async {
    final controller = TextEditingController(text: 'chapter2.rpy');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Script File'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    widget.project.scripts.add(ScriptFile(
      id: _uuid.v4(),
      fileName: name.endsWith('.rpy') ? name : '$name.rpy',
      lines: [
        DialogueLine(id: _uuid.v4(), kind: DialogueKind.label, text: 'chapter2'),
      ],
    ));
    setState(() => _scriptIndex = widget.project.scripts.length - 1);
    _persist();
  }

  void _addLine(DialogueKind kind) {
    final line = DialogueLine(
      id: _uuid.v4(),
      kind: kind,
      speakerVarName: kind == DialogueKind.say && widget.project.characters.isNotEmpty
          ? widget.project.characters.first.varName
          : null,
      text: _defaultTextFor(kind),
      menuOptions: kind == DialogueKind.menuChoice
          ? [MenuOption(label: 'Choice A', jumpTarget: 'label_a')]
          : [],
    );
    setState(() => _script.lines.add(line));
    _persist();
  }

  String _defaultTextFor(DialogueKind kind) {
    switch (kind) {
      case DialogueKind.say:
        return "Hey, over here!";
      case DialogueKind.narration:
        return 'The room falls silent.';
      case DialogueKind.sceneShow:
        return 'scene bg room';
      case DialogueKind.label:
        return 'new_label';
      case DialogueKind.jump:
        return 'start';
      case DialogueKind.comment:
        return 'TODO: revise this beat';
      case DialogueKind.menuChoice:
        return '';
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _script.lines.removeAt(oldIndex);
      _script.lines.insert(newIndex, item);
    });
    _persist();
  }

  void _deleteLine(DialogueLine line) {
    setState(() => _script.lines.remove(line));
    _persist();
  }

  void _addCharacter() async {
    final nameCtrl = TextEditingController();
    final varCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Character'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: varCtrl,
              decoration:
                  const InputDecoration(labelText: 'Script variable (e.g. "m")'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (result != true) return;
    if (nameCtrl.text.trim().isEmpty || varCtrl.text.trim().isEmpty) return;
    widget.project.characters.add(Character(
      id: _uuid.v4(),
      varName: varCtrl.text.trim(),
      displayName: nameCtrl.text.trim(),
    ));
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.project.scripts.isEmpty) {
      return Center(
        child: FilledButton.icon(
          onPressed: _addScriptFile,
          icon: const Icon(Icons.add),
          label: const Text('Add a script file'),
        ),
      );
    }

    return Column(
      children: [
        // Script file tabs
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: widget.project.scripts.length,
                  itemBuilder: (context, i) {
                    final selected = i == _scriptIndex;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: ChoiceChip(
                        label: Text(widget.project.scripts[i].fileName),
                        selected: selected,
                        onSelected: (_) => setState(() => _scriptIndex = i),
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                  onPressed: _addScriptFile, icon: const Icon(Icons.add)),
            ],
          ),
        ),
        const Divider(height: 1),
        CharacterChipBar(
          characters: widget.project.characters,
          onAdd: _addCharacter,
        ),
        const Divider(height: 1),
        // Toolbar to insert new blocks
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            spacing: 6,
            children: [
              _AddButton(label: 'Say', icon: Icons.chat_bubble_outline,
                  onTap: () => _addLine(DialogueKind.say)),
              _AddButton(label: 'Narration', icon: Icons.short_text,
                  onTap: () => _addLine(DialogueKind.narration)),
              _AddButton(label: 'Scene/Show', icon: Icons.landscape_outlined,
                  onTap: () => _addLine(DialogueKind.sceneShow)),
              _AddButton(label: 'Menu', icon: Icons.list_alt_outlined,
                  onTap: () => _addLine(DialogueKind.menuChoice)),
              _AddButton(label: 'Label', icon: Icons.label_outline,
                  onTap: () => _addLine(DialogueKind.label)),
              _AddButton(label: 'Jump', icon: Icons.arrow_forward,
                  onTap: () => _addLine(DialogueKind.jump)),
              _AddButton(label: 'Comment', icon: Icons.comment_outlined,
                  onTap: () => _addLine(DialogueKind.comment)),
              IconButton(
                tooltip: 'View compiled Ren\'Py',
                icon: Icon(_showRaw ? Icons.edit_note : Icons.code),
                onPressed: () => setState(() => _showRaw = !_showRaw),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _showRaw ? _RawPreview(script: _script) : _buildLineList(),
        ),
      ],
    );
  }

  Widget _buildLineList() {
    if (_script.lines.isEmpty) {
      return Center(
        child: Text('No lines yet — add one above.',
            style: TextStyle(color: Colors.white.withOpacity(0.4))),
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
      itemCount: _script.lines.length,
      onReorder: _reorder,
      itemBuilder: (context, i) {
        final line = _script.lines[i];
        return DialogueLineTile(
          key: ValueKey(line.id),
          line: line,
          characters: widget.project.characters,
          onChanged: _persist,
          onDelete: () => _deleteLine(line),
        );
      },
    );
  }
}

class _RawPreview extends StatelessWidget {
  final ScriptFile script;
  const _RawPreview({required this.script});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F0F14),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: SelectableText(
          script.compile(),
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 13, color: Color(0xFFE0E0E8)),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _AddButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
