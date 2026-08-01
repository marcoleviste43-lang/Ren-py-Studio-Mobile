import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/renpy_project.dart';
import '../models/character.dart';
import '../models/script_file.dart';
import '../models/dialogue_line.dart';

const _uuid = Uuid();

/// Central state holder for all projects. Handles on-disk creation of the
/// Ren'Py folder skeleton (game/images, game/audio, game/gui) and
/// persists project metadata as JSON via SharedPreferences.
class ProjectService extends ChangeNotifier {
  static const _storageKey = 'renpy_studio.projects';

  final List<RenPyProject> _projects = [];
  RenPyProject? activeProject;
  bool loading = true;

  List<RenPyProject> get projects => List.unmodifiable(_projects);

  Future<void> init() async {
    loading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    _projects
      ..clear()
      ..addAll(raw.map((s) => RenPyProject.decode(s)));
    loading = false;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _storageKey, _projects.map((p) => p.encode()).toList());
  }

  Future<Directory> _rootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, 'RenPyStudioProjects'));
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  /// Creates a brand new project with the standard Ren'Py folder layout
  /// and a starter script.rpy containing a `start` label.
  Future<RenPyProject> createProject(String name) async {
    final root = await _rootDir();
    final safeName = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '');
    final dir = Directory(p.join(root.path, safeName));
    await dir.create(recursive: true);

    for (final sub in ['game', 'game/images', 'game/audio', 'game/gui']) {
      await Directory(p.join(dir.path, sub)).create(recursive: true);
    }

    final now = DateTime.now();
    final starterLabel = DialogueLine(
      id: _uuid.v4(),
      kind: DialogueKind.label,
      text: 'start',
    );
    final starterLine = DialogueLine(
      id: _uuid.v4(),
      kind: DialogueKind.narration,
      text: 'Welcome to $name.',
    );

    final project = RenPyProject(
      id: _uuid.v4(),
      name: name,
      directoryPath: dir.path,
      createdAt: now,
      updatedAt: now,
      characters: [
        Character(
            id: _uuid.v4(),
            varName: 'e',
            displayName: 'Eileen',
            imageTag: 'eileen'),
      ],
      scripts: [
        ScriptFile(
          id: _uuid.v4(),
          fileName: 'script.rpy',
          lines: [starterLabel, starterLine],
        ),
      ],
    );

    _projects.add(project);
    await _persist();
    activeProject = project;
    notifyListeners();
    return project;
  }

  Future<void> updateProject(RenPyProject project) async {
    project.updatedAt = DateTime.now();
    final idx = _projects.indexWhere((p) => p.id == project.id);
    if (idx != -1) _projects[idx] = project;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteProject(RenPyProject project) async {
    _projects.removeWhere((p) => p.id == project.id);
    await _persist();
    try {
      final dir = Directory(project.directoryPath);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // best-effort cleanup; ignore filesystem errors on some platforms
    }
    if (activeProject?.id == project.id) activeProject = null;
    notifyListeners();
  }

  void setActive(RenPyProject project) {
    activeProject = project;
    notifyListeners();
  }

  /// Writes every script file's compiled contents to disk under game/.
  Future<void> saveScriptsToDisk(RenPyProject project) async {
    final gameDir = Directory(p.join(project.directoryPath, 'game'));
    if (!await gameDir.exists()) await gameDir.create(recursive: true);

    final defines = project.characters.map((c) => c.toRenPyDefine()).join('\n');

    for (final script in project.scripts) {
      final file = File(p.join(gameDir.path, script.fileName));
      final content = script.fileName == project.scripts.first.fileName
          ? '$defines\n\n${script.compile()}'
          : script.compile();
      await file.writeAsString(content);
    }
    await updateProject(project);
  }
}
