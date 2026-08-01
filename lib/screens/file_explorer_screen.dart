import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/renpy_project.dart';
import '../services/file_explorer_service.dart';
import 'raw_file_editor_screen.dart';

class FileExplorerScreen extends StatefulWidget {
  final RenPyProject project;
  const FileExplorerScreen({super.key, required this.project});

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  final _fs = FileExplorerService();
  late String _currentDir;
  List<FsEntry> _entries = [];
  final List<String> _breadcrumb = [];

  @override
  void initState() {
    super.initState();
    _currentDir = widget.project.directoryPath;
    _refresh();
  }

  Future<void> _refresh() async {
    final entries = await _fs.list(_currentDir);
    setState(() => _entries = entries);
  }

  void _open(FsEntry entry) {
    if (entry.isDirectory) {
      setState(() {
        _breadcrumb.add(p.basename(_currentDir));
        _currentDir = entry.path;
      });
      _refresh();
      return;
    }
    if (_isTextEditable(entry.name)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RawFileEditorScreen(filePath: entry.path),
        ),
      ).then((_) => _refresh());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entry.name} is not a text file preview.')),
      );
    }
  }

  bool _isTextEditable(String name) {
    const exts = ['.rpy', '.txt', '.json', '.rpyc', '.md'];
    return exts.any((e) => name.toLowerCase().endsWith(e));
  }

  void _goUp() {
    if (_breadcrumb.isEmpty) return;
    setState(() {
      _currentDir = p.dirname(_currentDir);
      _breadcrumb.removeLast();
    });
    _refresh();
  }

  Future<void> _newFileDialog() async {
    final controller = TextEditingController(text: 'new_scene.rpy');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New File'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _fs.createFile(_currentDir, name,
        contents: name.endsWith('.rpy') ? '# New Ren\'Py script\n' : '');
    _refresh();
  }

  Future<void> _newFolderDialog() async {
    final controller = TextEditingController(text: 'new_folder');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _fs.createFolder(_currentDir, name);
    _refresh();
  }

  IconData _iconFor(FsEntry e) {
    if (e.isDirectory) return Icons.folder;
    if (e.name.endsWith('.rpy')) return Icons.description_outlined;
    if (RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false)
        .hasMatch(e.name)) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final relative = _breadcrumb.isEmpty
        ? p.basename(widget.project.directoryPath)
        : '${p.basename(widget.project.directoryPath)}/${_breadcrumb.skip(1).join('/')}';

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                if (_breadcrumb.isNotEmpty)
                  IconButton(
                      onPressed: _goUp,
                      icon: const Icon(Icons.arrow_upward)),
                Expanded(
                  child: Text(
                    relative,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12.5),
                  ),
                ),
                IconButton(
                    onPressed: _newFolderDialog,
                    icon: const Icon(Icons.create_new_folder_outlined)),
                IconButton(
                    onPressed: _newFileDialog,
                    icon: const Icon(Icons.note_add_outlined)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Text('Empty folder',
                        style:
                            TextStyle(color: Colors.white.withOpacity(0.4))))
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      return ListTile(
                        leading: Icon(_iconFor(e)),
                        title: Text(e.name),
                        subtitle: e.isDirectory
                            ? null
                            : Text(_fs.formatSize(e.sizeBytes)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'delete') {
                              await _fs.deleteEntry(e);
                              _refresh();
                            } else if (v == 'rename') {
                              final controller =
                                  TextEditingController(text: e.name);
                              final newName = await showDialog<String>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Rename'),
                                  content: TextField(controller: controller),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel')),
                                    FilledButton(
                                        onPressed: () => Navigator.pop(
                                            ctx, controller.text.trim()),
                                        child: const Text('Rename')),
                                  ],
                                ),
                              );
                              if (newName != null && newName.isNotEmpty) {
                                await _fs.rename(e, newName);
                                _refresh();
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'rename', child: Text('Rename')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                        onTap: () => _open(e),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
