import 'dart:io';
import 'package:path/path.dart' as p;

class FsEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int sizeBytes;
  final DateTime modified;

  FsEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.sizeBytes,
    required this.modified,
  });
}

/// Thin wrapper around dart:io used to power the visual file explorer.
/// Scoped so callers can only browse inside a project's own directory.
class FileExplorerService {
  Future<List<FsEntry>> list(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final entities = await dir.list().toList();
    final entries = <FsEntry>[];
    for (final e in entities) {
      final stat = await e.stat();
      entries.add(FsEntry(
        name: p.basename(e.path),
        path: e.path,
        isDirectory: e is Directory,
        sizeBytes: stat.size,
        modified: stat.modified,
      ));
    }
    // folders first, then alphabetical
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  Future<String> readText(String filePath) => File(filePath).readAsString();

  Future<void> writeText(String filePath, String content) =>
      File(filePath).writeAsString(content);

  Future<void> deleteEntry(FsEntry entry) async {
    if (entry.isDirectory) {
      await Directory(entry.path).delete(recursive: true);
    } else {
      await File(entry.path).delete();
    }
  }

  Future<void> createFolder(String parentDir, String name) =>
      Directory(p.join(parentDir, name)).create(recursive: true);

  Future<File> createFile(String parentDir, String name,
      {String contents = ''}) async {
    final file = File(p.join(parentDir, name));
    await file.writeAsString(contents);
    return file;
  }

  Future<void> rename(FsEntry entry, String newName) async {
    final newPath = p.join(p.dirname(entry.path), newName);
    if (entry.isDirectory) {
      await Directory(entry.path).rename(newPath);
    } else {
      await File(entry.path).rename(newPath);
    }
  }

  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
