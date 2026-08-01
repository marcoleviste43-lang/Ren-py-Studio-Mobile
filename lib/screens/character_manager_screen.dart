import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/character.dart';
import '../models/renpy_project.dart';
import '../services/project_service.dart';

const _uuid = Uuid();

/// Lets the user view, add, edit, and delete the Character definitions
/// (`define e = Character(...)`) attached to a project.
class CharacterManagerScreen extends StatefulWidget {
  final RenPyProject project;
  const CharacterManagerScreen({super.key, required this.project});

  @override
  State<CharacterManagerScreen> createState() =>
      _CharacterManagerScreenState();
}

class _CharacterManagerScreenState extends State<CharacterManagerScreen> {
  void _persist() {
    context.read<ProjectService>().updateProject(widget.project);
    setState(() {});
  }

  Future<void> _openEditor({Character? existing}) async {
    final result = await showDialog<_CharacterFormResult>(
      context: context,
      builder: (ctx) => _CharacterFormDialog(existing: existing),
    );
    if (result == null) return;

    if (existing != null) {
      existing
        ..displayName = result.displayName
        ..varName = result.varName
        ..imageTag = result.imageTag
        ..color = result.color;
    } else {
      widget.project.characters.add(Character(
        id: _uuid.v4(),
        varName: result.varName,
        displayName: result.displayName,
        color: result.color,
        imageTag: result.imageTag,
      ));
    }
    _persist();
  }

  Future<void> _confirmDelete(Character character) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete character?'),
        content: Text(
          'This removes "${character.displayName}" (${character.varName}) '
          'from the project. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.project.characters.removeWhere((c) => c.id == character.id);
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final characters = widget.project.characters;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Characters'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Character'),
      ),
      body: characters.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups_outlined,
                        size: 64, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text('No characters yet',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Add a character to generate its Ren\'Py `define` line.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: characters.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final character = characters[i];
                return _CharacterCard(
                  character: character,
                  onEdit: () => _openEditor(existing: character),
                  onDelete: () => _confirmDelete(character),
                );
              },
            ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final Character character;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CharacterCard({
    required this.character,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: character.color.withOpacity(0.85),
          child: Text(
            character.displayName.isNotEmpty
                ? character.displayName[0].toUpperCase()
                : '?',
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(character.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Variable: ${character.varName}',
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12.5)),
              Text('Image tag: ${character.imageTag ?? '(none)'}',
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12.5)),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _CharacterFormResult {
  final String displayName;
  final String varName;
  final String? imageTag;
  final Color color;

  _CharacterFormResult({
    required this.displayName,
    required this.varName,
    required this.imageTag,
    required this.color,
  });
}

class _CharacterFormDialog extends StatefulWidget {
  final Character? existing;
  const _CharacterFormDialog({this.existing});

  @override
  State<_CharacterFormDialog> createState() => _CharacterFormDialogState();
}

class _CharacterFormDialogState extends State<_CharacterFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _varNameCtrl;
  late final TextEditingController _imageTagCtrl;
  late final TextEditingController _colorHexCtrl;
  Color _previewColor = Colors.white;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _displayNameCtrl = TextEditingController(text: c?.displayName ?? '');
    _varNameCtrl = TextEditingController(text: c?.varName ?? '');
    _imageTagCtrl = TextEditingController(text: c?.imageTag ?? '');
    _previewColor = c?.color ?? Colors.white;
    _colorHexCtrl = TextEditingController(text: _colorToHex(_previewColor));
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _varNameCtrl.dispose();
    _imageTagCtrl.dispose();
    _colorHexCtrl.dispose();
    super.dispose();
  }

  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}'
        .toUpperCase();
  }

  static Color? _hexToColor(String input) {
    var hex = input.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 3) {
      // shorthand e.g. "0f0" -> "00ff00"
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length != 6) return null;
    final value = int.tryParse('FF$hex', radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  String? _validateVarName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(v)) {
      return 'Must be a valid Python identifier';
    }
    return null;
  }

  String? _validateDisplayName(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    return null;
  }

  String? _validateHex(String? value) {
    if (_hexToColor(value ?? '') == null) return 'Use hex like #FF6699';
    return null;
  }

  void _updateColorPreview(String value) {
    final parsed = _hexToColor(value);
    if (parsed != null) setState(() => _previewColor = parsed);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final color = _hexToColor(_colorHexCtrl.text) ?? Colors.white;
    Navigator.pop(
      context,
      _CharacterFormResult(
        displayName: _displayNameCtrl.text.trim(),
        varName: _varNameCtrl.text.trim(),
        imageTag: _imageTagCtrl.text.trim().isEmpty
            ? null
            : _imageTagCtrl.text.trim(),
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Character' : 'New Character'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _displayNameCtrl,
                decoration: const InputDecoration(labelText: 'Display Name'),
                validator: _validateDisplayName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _varNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Variable Name',
                  hintText: 'e.g. m, e, rival',
                ),
                validator: _validateVarName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageTagCtrl,
                decoration: const InputDecoration(
                  labelText: 'Image Tag',
                  hintText: 'e.g. eileen (optional)',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _colorHexCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Text Color (hex)',
                        hintText: '#FFFFFF',
                      ),
                      validator: _validateHex,
                      onChanged: _updateColorPreview,
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _previewColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
