import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/renpy_project.dart';
import '../services/ai/ai_action.dart';
import '../services/ai/ai_action_executor.dart';
import '../services/ai/ai_provider.dart';
import '../services/ai_service.dart';
import '../services/project_service.dart';
import '../widgets/ai_action_preview_card.dart';

class AiAssistantScreen extends StatefulWidget {
  final RenPyProject project;
  const AiAssistantScreen({super.key, required this.project});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  String? _error;

  Future<void> _openApiKeyDialog() async {
    final ai = context.read<AiService>();
    final provider = ai.availableProviders
        .firstWhere((p) => p.id == ai.selectedProvider);
    final controller = TextEditingController(text: provider.apiKey ?? '');
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${provider.displayName} API Key'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(hintText: provider.apiKeyHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (key != null && key.isNotEmpty) {
      await ai.setApiKeyFor(ai.selectedProvider, key);
    }
  }

  Future<void> _openProviderPicker() async {
    final ai = context.read<AiService>();
    final choice = await showDialog<AiProviderId>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('AI Provider'),
        children: ai.availableProviders
            .map((p) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, p.id),
                  child: Row(
                    children: [
                      Icon(
                        p.id == ai.selectedProvider
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(p.displayName),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (choice != null && choice != ai.selectedProvider) {
      await ai.setProvider(choice);
      if (!ai.isConfigured) {
        await _openApiKeyDialog();
      }
    }
  }

  final _executor = AiActionExecutor();

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final ai = context.read<AiService>();
    if (!ai.isConfigured) {
      await _openApiKeyDialog();
      if (!ai.isConfigured) return;
    }
    _inputController.clear();
    setState(() => _error = null);
    try {
      await ai.ask(text, project: widget.project);
      _scrollToBottom();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  /// Applies a confirmed AI-proposed script edit, persisting it via
  /// `ProjectService` and switching the target file to Raw Mode -- the
  /// only way any AI action ever changes a project.
  void _applyAction(AiScriptEditAction action) {
    final ai = context.read<AiService>();
    try {
      _executor.apply(widget.project, action, context.read<ProjectService>());
      ai.dismissAction(action);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Updated '${action.scriptFileName}'.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not apply change: $e')),
      );
    }
  }

  void _discardAction(AiScriptEditAction action) {
    context.read<AiService>().dismissAction(action);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiService>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('AI Assistant'),
        actions: [
          TextButton.icon(
            onPressed: _openProviderPicker,
            icon: const Icon(Icons.smart_toy_outlined, size: 18),
            label: Text(ai.availableProviders
                .firstWhere((p) => p.id == ai.selectedProvider)
                .displayName),
          ),
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'API Key',
            onPressed: _openApiKeyDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear chat',
            onPressed: ai.clearHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!ai.isConfigured)
            Container(
              width: double.infinity,
              color: Colors.amber.withOpacity(0.12),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add your ${ai.availableProviders.firstWhere((p) => p.id == ai.selectedProvider).displayName} '
                      'API key to enable the assistant.',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  TextButton(
                      onPressed: _openApiKeyDialog,
                      child: const Text('Add Key')),
                ],
              ),
            ),
          Expanded(
            child: ai.history.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Ask for scene ideas, character dialogue, branching '
                        'menu logic, or Ren\'Py syntax help. The assistant '
                        'knows your character list and script files, and can '
                        'propose edits to an existing file directly -- '
                        'you\'ll always get a preview to confirm first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: ai.history.length,
                    itemBuilder: (context, i) {
                      final msg = ai.history[i];
                      final isUser = msg.role == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.8),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.25)
                                : const Color(0xFF1B1B24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(
                            msg.content,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 13),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (ai.pendingActions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  for (final action in ai.pendingActions)
                    AiActionPreviewCard(
                      project: widget.project,
                      action: action,
                      onApply: () => _applyAction(action),
                      onDiscard: () => _discardAction(action),
                    ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'e.g. "Write a jealous rival\'s intro scene"',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ai.busy
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton.filled(
                          onPressed: _send,
                          icon: const Icon(Icons.send),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
