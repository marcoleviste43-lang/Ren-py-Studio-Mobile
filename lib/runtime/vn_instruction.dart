/// Runtime instructions for the Flutter-native VN Play engine (Phase 1).
///
/// This is a separate representation from [DialogueLine] in
/// `models/dialogue_line.dart` -- `DialogueLine` describes *authoring
/// intent* (what the visual editor stores and what `RenPyGenerator`
/// turns into `.rpy` text). These describe an already-resolved, linear,
/// executable program. `RuntimeCompiler` converts one into the other;
/// nothing here ever touches `RenPyGenerator` or export.
///
/// Labels do NOT become instructions -- `RuntimeCompiler` resolves them
/// into `CompiledScript.labelIndex` instead, so jumps/menu choices can
/// look up a target position directly.
library;

/// Base type for every executable instruction.
sealed class VnInstruction {
  const VnInstruction();
}

/// A line of dialogue. [speakerVarName] is null for narration (no
/// speaker line shown), matching how `DialogueLine.speakerVarName`
/// already works for `narration` vs `say` kinds.
class SayInstruction extends VnInstruction {
  final String? speakerVarName;
  final String text;

  const SayInstruction({this.speakerVarName, required this.text});
}

/// A single selectable option inside a [MenuInstruction].
class VnChoice {
  final String text;
  final String targetLabel;

  const VnChoice({required this.text, required this.targetLabel});
}

/// A branch point. Playback pauses until the player picks one of
/// [choices]; picking one jumps to that choice's `targetLabel`.
class MenuInstruction extends VnInstruction {
  final List<VnChoice> choices;

  const MenuInstruction(this.choices);
}

/// Unconditional jump to a label. Unlike Say/Menu, this executes
/// automatically -- the engine resolves `targetLabel` via
/// `CompiledScript.labelIndex` and keeps going without waiting on input.
class JumpInstruction extends VnInstruction {
  final String targetLabel;

  const JumpInstruction(this.targetLabel);
}

/// Marks the end of playback. Always the last instruction in a
/// `CompiledScript` -- `RuntimeCompiler` appends it automatically so
/// the engine never has to bounds-check past the end of the list.
class EndInstruction extends VnInstruction {
  const EndInstruction();
}
