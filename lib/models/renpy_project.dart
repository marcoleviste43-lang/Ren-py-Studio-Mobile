import 'dart:convert';
import 'character.dart';
import 'script_file.dart';

/// Represents a single Ren'Py project managed by the studio.
/// Mirrors the folder layout Ren'Py itself expects:
///   game/
///     script.rpy
///     images/
///     audio/
///     gui/
class RenPyProject {
  String id;
  String name;
  String directoryPath; // absolute path on device storage
  DateTime createdAt;
  DateTime updatedAt;
  List<Character> characters;
  List<ScriptFile> scripts; // one or more .rpy files
  List<String> importedImagePaths; // paths inside game/images

  RenPyProject({
    required this.id,
    required this.name,
    required this.directoryPath,
    required this.createdAt,
    required this.updatedAt,
    List<Character>? characters,
    List<ScriptFile>? scripts,
    List<String>? importedImagePaths,
  })  : characters = characters ?? [],
        scripts = scripts ?? [],
        importedImagePaths = importedImagePaths ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'directoryPath': directoryPath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'characters': characters.map((c) => c.toJson()).toList(),
        'scripts': scripts.map((s) => s.toJson()).toList(),
        'importedImagePaths': importedImagePaths,
      };

  factory RenPyProject.fromJson(Map<String, dynamic> json) => RenPyProject(
        id: json['id'],
        name: json['name'],
        directoryPath: json['directoryPath'],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        characters: (json['characters'] as List? ?? [])
            .map((c) => Character.fromJson(c))
            .toList(),
        scripts: (json['scripts'] as List? ?? [])
            .map((s) => ScriptFile.fromJson(s))
            .toList(),
        importedImagePaths:
            List<String>.from(json['importedImagePaths'] ?? []),
      );

  String encode() => jsonEncode(toJson());
  factory RenPyProject.decode(String source) =>
      RenPyProject.fromJson(jsonDecode(source));
}
