import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/renpy_project.dart';
import 'runtime_compiler.dart';
import 'vn_engine.dart';
import 'vn_instruction.dart';

/// Phase 1 of Play mode: no images, no backgrounds, no transitions --
/// just narration, character dialogue, and menu choices, enough to
/// prove "press Play and watch the story run" end to end. Images and
/// scene rendering are a separate, later phase (see the architecture
/// doc); this screen is deliberately text-only so that phase can land
/// without reshaping anything built here.
class PlayerScreen extends StatefulWidget {
  final RenPyProject project;
  const PlayerScreen({super.key, required this.project});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final CompileResult _result;
  VnEngine? _engine;

  @override
  void initState() {
    super.initState();
    _result = RuntimeCompiler().compile(widget.project);
    if (_result.success) {
      _engine = VnEngine(_result.script!);
      if (_result.warnings.isNotEmpty) {
        // Errors block Play entirely (see build()); warnings don't, but
        // still deserve a heads-up. One SnackBar after first frame is
        // enough for Phase 1 -- a dedicated warnings panel can come
        // later if projects start accumulating more than one.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_result.warnings.first),
              duration: const Duration(seconds: 4),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_result.success) {
      return _CompileErrorScreen(
        result: _result,
        projectName: widget.project.name,
      );
    }
    return AnimatedBuilder(
      animation: _engine!,
      builder: (context, _) => _PlaybackView(engine: _engine!),
    );
  }
}

class _PlaybackView extends StatelessWidget {
  final VnEngine engine;
  const _PlaybackView({required this.engine});

  @override
  Widget build(BuildContext context) {
    final instr = engine.current;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(title: const Text('Play')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: engine.status == VnEngineStatus.playing ? engine.advance : null,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (engine.status) {
              VnEngineStatus.finished => const _EndView(),
              VnEngineStatus.waitingForChoice => _MenuView(
                  instruction: instr as MenuInstruction,
                  engine: engine,
                ),
              VnEngineStatus.playing => _DialogueView(
                  instruction: instr as SayInstruction,
                  characters: engine.script.characters,
                ),
            },
          ),
        ),
      ),
    );
  }
}

class _DialogueView extends StatelessWidget {
  final SayInstruction instruction;
  final Map<String, Character> characters;
  const _DialogueView({required this.instruction, required this.characters});

  @override
  Widget build(BuildContext context) {
    final character = instruction.speakerVarName == null
        ? null
        : characters[instruction.speakerVarName];
    // Falls back to the raw variable name if the character was deleted
    // or renamed since the line was written -- still shows *something*
    // rather than silently dropping the speaker.
    final speakerLabel = character?.displayName ?? instruction.speakerVarName;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (speakerLabel != null) ...[
              Text(
                '$speakerLabel:',
                style: TextStyle(
                  color: character?.color ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              '"${instruction.text}"',
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.touch_app_outlined,
                  size: 16, color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuView extends StatelessWidget {
  final MenuInstruction instruction;
  final VnEngine engine;
  const _MenuView({required this.instruction, required this.engine});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final choice in instruction.choices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  // Tapping a choice must not also trigger the parent
                  // GestureDetector's advance() -- HitTestBehavior.opaque
                  // on the parent only fires when nothing else consumes
                  // the tap, and this button consumes it, so no extra
                  // guard is needed here.
                  onPressed: () => engine.choose(choice),
                  child: Text(choice.text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EndView extends StatelessWidget {
  const _EndView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, color: Colors.white54, size: 40),
          SizedBox(height: 12),
          Text('-- End --', style: TextStyle(color: Colors.white70, fontSize: 18)),
        ],
      ),
    );
  }
}

class _CompileErrorScreen extends StatelessWidget {
  final CompileResult result;
  final String projectName;
  const _CompileErrorScreen({
    required this.result,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Can't play $projectName")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (result.errors.isNotEmpty) ...[
            const Text('Errors',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.redAccent)),
            const SizedBox(height: 8),
            for (final e in result.errors)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $e'),
              ),
            const SizedBox(height: 16),
          ],
          if (result.warnings.isNotEmpty) ...[
            const Text('Warnings',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 8),
            for (final w in result.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $w'),
              ),
          ],
        ],
      ),
    );
  }
}
