import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/renpy_project.dart';
import '../services/ai_service.dart';

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
    final controller = TextEditingController(text: ai.apiKey ?? '');
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anthropic API Key'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'sk-ant-...'),
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
      await ai.setApiKey(key);
    }
  }

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
      final context_ = _buildProjectContext();
      await ai.ask(text, projectContext: context_);
      _scrollToBottom();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  String _buildProjectContext() {
    final chars = widget.project.characters
        .map((c) => '${c.varName}="${c.displayName}"')
        .join(', ');
    final scriptNames =
        widget.project.scripts.map((s) => s.fileName).join(', ');
    return 'Project "${widget.project.name}". Characters: $chars. '
        'Script files: $scriptNames.';
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
                  const Expanded(
                    child: Text(
                      'Add your Anthropic API key to enable the assistant.',
                      style: TextStyle(fontSize: 12.5),
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
                        'knows your character list and script files.',
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
