import 'package:flutter/material.dart';

import '../models/renpy_project.dart';
import '../services/ai/ai_action.dart';
import '../services/ai/ai_action_executor.dart';

/// Confirmation card for a single [AiScriptEditAction]. Always shown
/// before an AI-proposed edit is applied -- this is the only path that
/// leads to `AiActionExecutor.apply()` being called.
class AiActionPreviewCard extends StatelessWidget {
  final RenPyProject project;
  final AiScriptEditAction action;
  final VoidCallback onApply;
  final VoidCallback onDiscard;

  const AiActionPreviewCard({
    super.key,
    required this.project,
    required this.action,
    required this.onApply,
    required this.onDiscard,
  });

  String get _modeLabel {
    switch (action.mode) {
      case AiEditMode.append:
        return 'Append';
      case AiEditMode.replace:
        return 'Replace whole file';
      case AiEditMode.rewrite:
        return 'Rewrite section';
    }
  }

  @override
  Widget build(BuildContext context) {
    String? preview;
    String? error;
    try {
      preview = AiActionExecutor().preview(project, action);
    } catch (e) {
      error = e.toString().replaceFirst('StateError: ', '');
    }

    return Card(
      color: const Color(0xFF1B1B24),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'AI wants to edit ${action.scriptFileName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_modeLabel,
                      style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
            if (action.summary != null && action.summary!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(action.summary!,
                  style: TextStyle(color: Colors.white.withOpacity(0.75))),
            ],
            const SizedBox(height: 10),
            if (error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(error,
                            style: const TextStyle(fontSize: 12.5))),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    preview ?? '',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFFE0E0E8)),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              "Applying this switches '${action.scriptFileName}' to Raw "
              'Mode, same as a manual raw edit.',
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withOpacity(0.4)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onDiscard, child: const Text('Discard')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: error == null ? onApply : null,
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
