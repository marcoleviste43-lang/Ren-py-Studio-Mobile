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

  /// Writes edited raw text back into the model. This is the only path
  /// that sets `rawOverride` -- once set, `ScriptFile.isRawMode` is true
  /// and this file's `lines` are considered stale until the raw edits
  /// are explicitly discarded (there's no parser to reconcile the two).
  void _saveRawOverride(String text) {
    _script.rawOverride = text;
    _persist();
  }

  /// Drops the raw override and falls back to whatever `lines` still
  /// holds, returning the file to Visual Mode. This does not parse the
  /// raw text -- it discards it -- so it's only offered with an explicit
  /// confirmation.
  Future<void> _discardRawMode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard raw edits?'),
        content: const Text(
          'This switches the file back to Visual Mode using the blocks '
          'from before it was last hand-edited. The raw text you typed '
          'will be discarded -- this can\'t be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _script.rawOverride = null);
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
        if (_script.isRawMode) _RawModeBanner(onDiscard: _discardRawMode),
        // Toolbar to insert new blocks -- hidden in Raw Mode, since
        // `lines` is stale there and adding blocks wouldn't affect the
        // compiled output (`rawOverride` always wins).
        if (!_script.isRawMode)
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
                  tooltip: 'Edit raw Ren\'Py',
                  icon: Icon(_showRaw ? Icons.edit_note : Icons.code),
                  onPressed: () => setState(() => _showRaw = !_showRaw),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Text('RAW MODE',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.withOpacity(0.9))),
                const Spacer(),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: (_showRaw || _script.isRawMode)
              ? _RawEditor(
                  key: ValueKey(_script.id),
                  script: _script,
                  onSave: _saveRawOverride,
                )
              : _buildLineList(),
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

/// Editable code editor for a `ScriptFile`'s raw Ren'Py text. Replaces
/// the old read-only preview: edits are held locally until the user taps
/// Save, at which point [onSave] writes the *exact* text typed --
/// nothing here reformats, trims, or reflows it -- into `rawOverride`.
///
/// Keyed by the script's id from the caller so switching file tabs
/// tears down and rebuilds this widget's state, re-seeding the
/// controller from that file's current text instead of carrying over
/// another file's edits.
class _RawEditor extends StatefulWidget {
  final ScriptFile script;
  final ValueChanged<String> onSave;
  const _RawEditor({super.key, required this.script, required this.onSave});

  @override
  State<_RawEditor> createState() => _RawEditorState();
}

class _RawEditorState extends State<_RawEditor> {
  late final TextEditingController _controller;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    // Seed from rawOverride if this file is already in Raw Mode;
    // otherwise from the compiled output of the current blocks, so the
    // very first edit starts from exactly what the user was just
    // looking at.
    _controller = TextEditingController(
        text: widget.script.rawOverride ?? widget.script.compile());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(_controller.text);
    setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF16161D),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.code, size: 16, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text(
                widget.script.fileName,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6)),
              ),
              const Spacer(),
              if (_dirty)
                FilledButton.tonalIcon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Save'),
                )
              else
                Text('Saved',
                    style: TextStyle(
                        fontSize: 11, color: Colors.white.withOpacity(0.35))),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            width: double.infinity,
            color: const Color(0xFF0F0F14),
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) {
                if (!_dirty) setState(() => _dirty = true);
              },
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFFE0E0E8)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '# Ren\'Py script text…',
                hintStyle: TextStyle(color: Colors.white24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown at the top of a script file's tab once it's in Raw Mode,
/// explaining why the visual block editor is unavailable and offering
/// the only way back (discarding the raw edits -- see
/// `_DialogueEditorScreenState._discardRawMode`).
class _RawModeBanner extends StatelessWidget {
  final VoidCallback onDiscard;
  const _RawModeBanner({required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'This file was hand-edited as raw text. Visual Mode is '
              'unavailable while it\'s in Raw Mode -- edit it below, or '
              'discard the raw edits to go back to blocks.',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: onDiscard,
            child: const Text('Discard'),
          ),
        ],
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
