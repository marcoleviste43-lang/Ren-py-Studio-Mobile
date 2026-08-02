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
            final name = line.text.trim();
            if (name.isEmpty) {
              errors.add("Empty label name in '${script.fileName}'.");
              break;
            }
            if (labelIndex.containsKey(name)) {
              errors.add(
                  "Duplicate label '$name' (seen again in '${script.fileName}').");
              break;
            }
            // Mirrors ScriptFile.compile()'s auto-`return`: without
            // this, a label with no explicit jump would silently fall
            // through into whatever label happens to sit next in this
            // flat instruction list -- the exact bug being fixed here.
            _closeLabelIfUnterminated(instructions);
            labelIndex[name] = instructions.length;
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

  /// If the label currently being built ended without an explicit
  /// [JumpInstruction] or an all-jump [MenuInstruction] (verified
  /// against the actual choice data by [_menuAlwaysJumps], not assumed
  /// from the instruction's type alone), it would otherwise fall
  /// through into the next label added to [instructions]. Insert an
  /// [EndInstruction] as a safety net -- equivalent to Ren'Py's
  /// implicit `return` at a label with no caller.
  void _closeLabelIfUnterminated(List<VnInstruction> instructions) {
    if (instructions.isEmpty) return;
    final last = instructions.last;
    if (last is EndInstruction) return;
    if (last is JumpInstruction) return;
    if (last is MenuInstruction && _menuAlwaysJumps(last)) return;
    instructions.add(const EndInstruction());
  }

  /// Mirrors `ScriptFile._menuAlwaysJumps`: a menu only counts as
  /// guaranteeing hand-off if every choice actually has a non-blank
  /// target. A blank `targetLabel` (reachable today by clearing the
  /// jump-target field in the dialogue editor) would otherwise be
  /// treated as "safe" here and then surface only as a separate
  /// "undefined label ''" error below -- checking the real data keeps
  /// this method's own guarantee honest regardless of what else does
  /// or doesn't catch it downstream.
  bool _menuAlwaysJumps(MenuInstruction menu) {
    if (menu.choices.isEmpty) return false;
    return menu.choices.every((c) => c.targetLabel.trim().isNotEmpty);
  }
}
