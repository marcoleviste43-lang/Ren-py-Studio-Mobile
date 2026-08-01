import '../models/renpy_project.dart';
import '../models/script_file.dart';

/// Turns a [RenPyProject]'s structured data (characters + script files)
/// into valid Ren'Py (`.rpy`) source text.
///
/// This is the single place that combines character `define` statements
/// with compiled script bodies. Every feature that needs generated script
/// text -- the live Preview tab, on-device sync (`ProjectService`), and
/// the `.zip` exporter (`RenPyExportService`) -- calls into this class
/// instead of re-implementing the "defines + compile" logic themselves,
/// so the three can never drift out of sync with each other.
class RenPyGenerator {
  /// Renders every character's `define` statement, one per line. Returns
  /// an empty string if the project has no characters yet.
  String generateCharacterDefines(RenPyProject project) {
    if (project.characters.isEmpty) return '';
    return project.characters.map((c) => c.toRenPyDefine()).join('\n');
  }

  /// Compiles a single [ScriptFile] to Ren'Py source. When [includeDefines]
  /// is true, the project's character `define` block is prepended -- used
  /// for whichever file is conventionally "first" so defines only appear
  /// once across the whole project.
  String generateScript(
    RenPyProject project,
    ScriptFile script, {
    bool includeDefines = false,
  }) {
    final body = script.compile();
    if (!includeDefines) return body;
    final defines = generateCharacterDefines(project);
    return defines.isEmpty ? body : '$defines\n\n$body';
  }

  /// Compiles every script file in the project, keyed by file name, ready
  /// to be written to disk as-is. Character defines are prepended to the
  /// first script file only, matching how a typical Ren'Py project keeps
  /// its `define` block near the top of `script.rpy`.
  Map<String, String> generateAllFiles(RenPyProject project) {
    final files = <String, String>{};
    for (var i = 0; i < project.scripts.length; i++) {
      final script = project.scripts[i];
      files[script.fileName] =
          generateScript(project, script, includeDefines: i == 0);
    }
    return files;
  }

  /// Produces one combined, human-readable rendering of the entire
  /// project: character defines up top, followed by every script file
  /// with a comment header marking where each file begins. This powers
  /// both the live Preview tab and "export current script as one .rpy".
  String generateCombinedPreview(RenPyProject project) {
    final buffer = StringBuffer();

    final defines = generateCharacterDefines(project);
    if (defines.isNotEmpty) {
      buffer.writeln('# Characters');
      buffer.writeln(defines);
      buffer.writeln();
    }

    if (project.scripts.isEmpty) {
      buffer.writeln('# No script files yet -- add one in the Dialogue tab.');
      return buffer.toString();
    }

    for (final script in project.scripts) {
      buffer.writeln('# ---- ${script.fileName} ----');
      final body = script.compile().trimRight();
      buffer.writeln(body.isEmpty ? '# (empty)' : body);
      buffer.writeln();
    }

    return buffer.toString().trimRight();
  }
}
