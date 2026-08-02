import '../models/character.dart';
import '../models/dialogue_line.dart';
import '../models/renpy_project.dart';
import 'compiled_script.dart';
import 'vn_instruction.dart';

/// Result of [RuntimeCompiler.compile]. `errors` block playback entirely
/// (`PlayerScreen` shows them instead of trying to run); `warnings` are
/// shown but don't stop playback (e.g. a raw-edited file gets skipped,
/// or a character variable isn't recognized).
class CompileResult {
  final CompiledScript? script;
  final List<String> errors;
  final List<String> warnings;

  const CompileResult({
    this.script,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get success => errors.isEmpty && script != null;
}

/// Converts a project's characters + script files directly into a
/// [CompiledScript] -- reading the same `DialogueLine` structures
/// `RenPyGenerator` reads, but producing an executable instruction list
/// instead of `.rpy` text. Never calls into `RenPyGenerator` and never
/// writes anything back to the project; this is a pure read-only
/// compile step.
class RuntimeCompiler {
  CompileResult compile(RenPyProject project) {
    final instructions = <VnInstruction>[];
    final labelIndex = <String, int>{};
    final errors = <String>[];
    final warnings = <String>[];

    final characters = <String, Character>{
      for (final c in project.characters) c.varName: c,
    };

    for (final script in project.scripts) {
      // Phase 1 only interprets the structured block list. Hand-edited
      // raw text can't be safely run without a full text parser, so it
      // is skipped with a warning rather than guessed at.
      if (script.rawOverride != null) {
        warnings.add(
          "Skipped '${script.fileName}': it was hand-edited as raw text, "
          "which Play mode can't run yet. Edit it in the Dialogue tab to "
          "make it playable, or test it in the Ren'Py desktop launcher.",
        );
        continue;
      }

      for (final line in script.lines) {
        switch (line.kind) {
          case DialogueKind.label:
            _addLabel(line.text.trim(), script.fileName, instructions.length,
                labelIndex, errors);
            break;

          case DialogueKind.say:
            if (line.speakerVarName != null &&
                !characters.containsKey(line.speakerVarName)) {
              warnings.add(
                "'${script.fileName}': a line speaks as unknown character "
                "'${line.speakerVarName}' -- add it in Characters, or it "
                'will play back with no name shown.',
              );
            }
            instructions.add(SayInstruction(
              speakerVarName: line.speakerVarName,
              text: line.text,
            ));
            break;

          case DialogueKind.narration:
            instructions.add(SayInstruction(text: line.text));
            break;

          case DialogueKind.menuChoice:
            instructions.add(MenuInstruction([
              for (final opt in line.menuOptions)
                VnChoice(text: opt.label, targetLabel: opt.jumpTarget),
            ]));
            break;

          case DialogueKind.jump:
            instructions.add(JumpInstruction(line.text.trim()));
            break;

          case DialogueKind.sceneShow:
            // Phase 1 has no images/backgrounds -- scene/show lines are
            // recognized but produce no instruction. Revisit once the
            // scene/sprite system lands.
            break;

          case DialogueKind.comment:
            // Comments don't affect playback.
            break;
        }
      }
    }

    instructions.add(const EndInstruction());

    // Validate every jump target now that all labels in the project are
    // known, so a broken reference is a readable error instead of a
    // null-check crash mid-playback.
    for (final instr in instructions) {
      if (instr is JumpInstruction &&
          !labelIndex.containsKey(instr.targetLabel)) {
        errors.add("Jump to undefined label '${instr.targetLabel}'.");
      } else if (instr is MenuInstruction) {
        for (final choice in instr.choices) {
          if (!labelIndex.containsKey(choice.targetLabel)) {
            errors.add(
              "Menu choice '${choice.text}' jumps to undefined label "
              "'${choice.targetLabel}'.",
            );
          }
        }
      }
    }

    if (errors.isNotEmpty) {
      return CompileResult(errors: errors, warnings: warnings);
    }

    return CompileResult(
      script: CompiledScript(
        instructions: instructions,
        labelIndex: labelIndex,
        characters: characters,
      ),
      warnings: warnings,
    );
  }

  void _addLabel(
    String name,
    String fileName,
    int position,
    Map<String, int> labelIndex,
    List<String> errors,
  ) {
    if (name.isEmpty) {
      errors.add("Empty label name in '$fileName'.");
      return;
    }
    if (labelIndex.containsKey(name)) {
      errors.add("Duplicate label '$name' (seen again in '$fileName').");
      return;
    }
    labelIndex[name] = position;
  }
}
