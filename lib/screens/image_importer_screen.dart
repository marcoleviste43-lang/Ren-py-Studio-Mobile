import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

import '../models/renpy_project.dart';
import '../services/image_import_service.dart';
import '../services/project_service.dart';

class ImageImporterScreen extends StatefulWidget {
  final RenPyProject project;
  const ImageImporterScreen({super.key, required this.project});

  @override
  State<ImageImporterScreen> createState() => _ImageImporterScreenState();
}

class _ImageImporterScreenState extends State<ImageImporterScreen> {
  final _importer = ImageImportService();
  bool _busy = false;

  Future<void> _importFromGallery() async {
    setState(() => _busy = true);
    try {
      final picked = await _importer.pickFromGallery();
      for (final img in picked) {
        final renamed = await _promptRename(img.suggestedTag);
        if (renamed == null) continue; // skipped
        final destPath = await _importer.importInto(
          widget.project.directoryPath,
          img,
          renameTo: renamed,
        );
        widget.project.importedImagePaths.add(destPath);
      }
      await context.read<ProjectService>().updateProject(widget.project);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromCamera() async {
    setState(() => _busy = true);
    try {
      final img = await _importer.pickFromCamera();
      if (img == null) return;
      final renamed = await _promptRename(img.suggestedTag);
      if (renamed == null) return;
      final destPath = await _importer.importInto(
        widget.project.directoryPath,
        img,
        renameTo: renamed,
      );
      widget.project.importedImagePaths.add(destPath);
      await context.read<ProjectService>().updateProject(widget.project);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptRename(String suggested) async {
    final controller = TextEditingController(text: suggested);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Image tag name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ren\'Py identifies images by their tag/filename '
              '(e.g. "eileen happy" -> eileen_happy.png). Adjust it below.',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 10),
            TextField(controller: controller, autofocus: true),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Skip')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(String path) async {
    widget.project.importedImagePaths.remove(path);
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await context.read<ProjectService>().updateProject(widget.project);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.project.importedImagePaths;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _importFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _importFromCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: images.isEmpty
                ? Center(
                    child: Text(
                      'No images imported yet.\nCharacter sprites and '
                      'backgrounds you add here land in game/images/.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.4)),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: images.length,
                    itemBuilder: (context, i) {
                      final path = images[i];
                      return Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  File(path).existsSync()
                                      ? Image.file(File(path), fit: BoxFit.cover)
                                      : Container(color: Colors.white10),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: InkWell(
                                      onTap: () => _remove(path),
                                      child: const CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.black54,
                                        child: Icon(Icons.close, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.basename(path),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
