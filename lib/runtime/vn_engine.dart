import 'package:flutter/foundation.dart';

import 'compiled_script.dart';
import 'vn_instruction.dart';

/// What the engine is doing right now, for `PlayerScreen` to key its UI
/// off of without inspecting `current`'s runtime type itself.
enum VnEngineStatus { playing, waitingForChoice, finished }

/// Executes a [CompiledScript] instruction by instruction.
///
/// Owns nothing about rendering -- `PlayerScreen` listens via
/// `ChangeNotifier` and reads [current]/[status] to decide what to draw.
/// This keeps the engine testable without Flutter widgets and keeps the
/// door open for a future scene/sprite state object without touching
/// this class's public shape.
class VnEngine extends ChangeNotifier {
  VnEngine(this.script) {
    _runToNextPause();
  }

  final CompiledScript script;

  int _ip = 0;
  VnEngineStatus status = VnEngineStatus.playing;

  /// The instruction currently waiting for input (a Say or a Menu), or
  /// the End instruction once playback has finished.
  VnInstruction get current => script.instructions[_ip];

  /// Advances `_ip` forward, executing anything that doesn't need input
  /// automatically, and stops on the next thing that does:
  /// - `JumpInstruction` resolves and loops immediately (no pause).
  /// - `MenuInstruction` pauses, waiting for [choose].
  /// - `SayInstruction` pauses, waiting for [advance].
  /// - `EndInstruction` marks playback finished.
  void _runToNextPause() {
    while (true) {
      final instr = script.instructions[_ip];

      if (instr is JumpInstruction) {
        _ip = script.labelIndex[instr.targetLabel]!;
        continue;
      }
      if (instr is EndInstruction) {
        status = VnEngineStatus.finished;
        return;
      }
      if (instr is MenuInstruction) {
        status = VnEngineStatus.waitingForChoice;
        return;
      }
      // SayInstruction
      status = VnEngineStatus.playing;
      return;
    }
  }

  /// Called when the player taps to move past the current dialogue
  /// line. No-op if a choice is pending or playback already finished.
  void advance() {
    if (status != VnEngineStatus.playing) return;
    _ip++;
    _runToNextPause();
    notifyListeners();
  }

  /// Called when the player taps a choice in the current menu. No-op if
  /// no menu is currently active.
  void choose(VnChoice choice) {
    if (status != VnEngineStatus.waitingForChoice) return;
    _ip = script.labelIndex[choice.targetLabel]!;
    _runToNextPause();
    notifyListeners();
  }
}
