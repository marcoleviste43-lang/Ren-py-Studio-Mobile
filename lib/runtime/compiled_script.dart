import '../models/character.dart';
import 'vn_instruction.dart';

/// An executable version of a `RenPyProject`: a flat, linear list of
/// [VnInstruction]s plus everything needed to resolve jumps and speaker
/// names at runtime. Produced once by `RuntimeCompiler`; read (never
/// mutated) by `VnEngine`.
class CompiledScript {
  /// Every instruction across all (non-raw-override) script files, in
  /// file order, with `label` lines removed and folded into
  /// [labelIndex] instead.
  final List<VnInstruction> instructions;

  /// Label name -> index into [instructions]. Every `JumpInstruction`
  /// and `VnChoice.targetLabel` is guaranteed (by `RuntimeCompiler`'s
  /// validation) to have a matching entry here.
  final Map<String, int> labelIndex;

  /// Character variable name -> `Character`, for resolving a
  /// `SayInstruction.speakerVarName` to a display name and color.
  final Map<String, Character> characters;

  const CompiledScript({
    required this.instructions,
    required this.labelIndex,
    required this.characters,
  });
}
