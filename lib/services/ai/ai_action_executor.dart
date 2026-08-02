import '../../models/renpy_project.dart';
import '../../models/script_file.dart';
import '../project_service.dart';
import 'ai_action.dart';

/// Computes and applies AI-proposed script edits.
///
/// [preview] never mutates anything -- it's used to render the
/// confirmation card. [apply] performs the same computation and then
/// writes the result into the target `ScriptFile.rawOverride`, which
/// is exactly what a manual raw edit does (see
/// `DialogueEditorScreen._saveRawOverride`), so an applied AI edit
/// leaves the file in Raw Mode just like a hand edit would.
class AiActionExecutor {
  /// Computes the resulting raw text for [action] without mutating
  /// [project]. Throws a [StateError] with a user-facing message if the
  /// action can't be applied as proposed (e.g. a `rewrite` whose
  /// `target` text can no longer be found).
  String preview(RenPyProject project, AiScriptEditAction action) {
    final script = _resolve(project, action);
    final current = script.rawOverride ?? script.compile();

    switch (action.mode) {
      case AiEditMode.append:
        if (current.trim().isEmpty) return action.content;
        final needsNewline = !current.endsWith('\n');
        return '$current${needsNewline ? '\n' : ''}${action.content}';

      case AiEditMode.replace:
        return action.content;

      case AiEditMode.rewrite:
        final target = action.target;
        if (target == null || target.isEmpty || !current.contains(target)) {
          throw StateError(
            "Couldn't find the text to rewrite in '${script.fileName}'. "
            'The file may have changed since this suggestion was made.',
          );
        }
        return current.replaceFirst(target, action.content);
    }
  }

  /// Applies [action] to [project] for real and persists the change via
  /// [projectService]. Only ever called after explicit user
  /// confirmation in the UI.
  void apply(
    RenPyProject project,
    AiScriptEditAction action,
    ProjectService projectService,
  ) {
    final script = _resolve(project, action);
    final resultText = preview(project, action);
    script.rawOverride = resultText;
    projectService.updateProject(project);
  }

  ScriptFile _resolve(RenPyProject project, AiScriptEditAction action) {
    for (final s in project.scripts) {
      if (s.id == action.scriptFileId) return s;
    }
    for (final s in project.scripts) {
      if (s.fileName == action.scriptFileName) return s;
    }
    throw StateError(
      "'${action.scriptFileName}' no longer exists in this project.",
    );
  }
}
