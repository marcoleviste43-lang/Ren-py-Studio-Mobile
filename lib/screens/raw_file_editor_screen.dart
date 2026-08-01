import 'package:flutter/material.dart';
import '../services/file_explorer_service.dart';
import 'package:path/path.dart' as p;

class RawFileEditorScreen extends StatefulWidget {
  final String filePath;
  const RawFileEditorScreen({super.key, required this.filePath});

  @override
  State<RawFileEditorScreen> createState() => _RawFileEditorScreenState();
}

class _RawFileEditorScreenState extends State<RawFileEditorScreen> {
  final _fs = FileExplorerService();
  final _controller = TextEditingController();
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final text = await _fs.readText(widget.filePath);
      _controller.text = text;
    } catch (_) {
      _controller.text = '';
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await _fs.writeText(widget.filePath, _controller.text);
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(widget.filePath)),
        actions: [
          IconButton(
            onPressed: _dirty ? _save : null,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                onChanged: (_) => setState(() => _dirty = true),
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 13.5, height: 1.5),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
              ),
            ),
    );
  }
}
