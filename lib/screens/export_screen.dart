import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/renpy_project.dart';
import '../services/renpy_export_service.dart';

class ExportScreen extends StatefulWidget {
  final RenPyProject project;
  const ExportScreen({super.key, required this.project});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _exportService = RenPyExportService();
  bool _busy = false;
  String? _resultPath;
  String? _error;

  Future<void> _exportZip() async {
    setState(() {
      _busy = true;
      _error = null;
      _resultPath = null;
    });
    try {
      final zipFile = await _exportService.exportZip(widget.project);
      setState(() => _resultPath = zipFile.path);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_resultPath == null) return;
    await Share.shareXFiles([XFile(_resultPath!)],
        text: '${widget.project.name} (Ren\'Py project export)');
  }

  Future<void> _materializeOnly() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _exportService.materialize(widget.project);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Project folder synced. Open it in the launcher '
                  'via the File Explorer or your device file manager.')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export "${widget.project.name}"',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Produces a folder with the standard Ren\'Py layout '
                    '(game/script.rpy, game/options.rpy, game/images, '
                    'game/audio, game/gui) that opens directly in the '
                    'Ren\'Py launcher, or zipped for sharing.',
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _materializeOnly,
            icon: const Icon(Icons.sync),
            label: const Text('Sync project folder on device'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _exportZip,
            icon: const Icon(Icons.folder_zip_outlined),
            label: const Text('Build .zip for export'),
          ),
          if (_busy) const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(minHeight: 3),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          if (_resultPath != null) ...[
            const SizedBox(height: 20),
            Card(
              color: Colors.green.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                        SizedBox(width: 8),
                        Text('Export ready'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(_resultPath!,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.share),
                      label: const Text('Share .zip'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
