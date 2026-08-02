import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/highlight_core.dart' show highlight;
import 'package:highlight/languages/python.dart' as python_lang;

import '../models/renpy_project.dart';
import '../services/project_service.dart';
import '../services/renpy_generator.dart';
import '../services/renpy_export_service.dart';
import '../runtime/player_screen.dart';

bool _renpyLanguageRegistered = false;

/// Ren'Py script is a Python superset (indentation-based blocks, `#`
/// comments, string literals, `def`/control flow inside python blocks),
/// so borrowing highlight.js's Python grammar gets strings, comments,
/// keywords, and numbers colored correctly without writing a bespoke
/// grammar just for the handful of extra Ren'Py statements (`label`,
/// `menu`, `jump`, `show`, `scene`). Registered once, lazily.
void _ensureRenPyLanguageRegistered() {
  if (_renpyLanguageRegistered) return;
  highlight.registerLanguage('renpy', python_lang.python);
  _renpyLanguageRegistered = true;
}

/// Live, read-only preview of the full Ren'Py script generated from the
/// project's current characters and script files. Rebuilds instantly
/// whenever any other tab persists a change via
/// `ProjectService.updateProject()`, since it watches that service
/// directly rather than caching generated text in its own state.
class PreviewScreen extends StatefulWidget {
  final RenPyProject project;
  const PreviewScreen({super.key, required this.project});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final _generator = RenPyGenerator();
  final _exportService = RenPyExportService();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _ensureRenPyLanguageRegistered();
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Script copied to clipboard')),
    );
  }

  Future<void> _exportRpy() async {
    setState(() => _exporting = true);
    try {
      final file = await _exportService.exportCombinedRpy(widget.project);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${widget.project.name} (Ren\'Py script preview)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watching ProjectService is what makes this "live": every other tab
    // (Dialogue, Characters, File Explorer's new-file actions) calls
    // updateProject() after mutating widget.project, which notifies this
    // listener and triggers a rebuild with freshly generated code.
    context.watch<ProjectService>();
    final code = _generator.generateCombinedPreview(widget.project);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Preview'),
        actions: [
          IconButton(
            tooltip: 'Play',
            icon: const Icon(Icons.play_arrow_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlayerScreen(project: widget.project),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Copy script',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () => _copy(code),
          ),
          IconButton(
            tooltip: 'Export as .rpy',
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined),
            onPressed: _exporting ? null : _exportRpy,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        color: const Color(0xFF0F0F14),
        child: SingleChildScrollView(
          child: HighlightView(
            code,
            language: 'renpy',
            theme: atomOneDarkTheme,
            padding: const EdgeInsets.all(16),
            textStyle: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
