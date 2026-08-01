import 'package:flutter/material.dart';

import '../models/renpy_project.dart';
import 'file_explorer_screen.dart';
import 'dialogue_editor_screen.dart';
import 'ai_assistant_screen.dart';
import 'image_importer_screen.dart';
import 'export_screen.dart';

/// Hosts the five core features as tabs: File Explorer, Dialogue Editor,
/// AI Assistant, Image Importer, and Export.
class ProjectWorkspaceScreen extends StatefulWidget {
  final RenPyProject project;
  const ProjectWorkspaceScreen({super.key, required this.project});

  @override
  State<ProjectWorkspaceScreen> createState() =>
      _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  int _index = 0;

  late final List<Widget> _tabs = [
    FileExplorerScreen(project: widget.project),
    DialogueEditorScreen(project: widget.project),
    AiAssistantScreen(project: widget.project),
    ImageImporterScreen(project: widget.project),
    ExportScreen(project: widget.project),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.project.name)),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Files'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Dialogue'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'AI'),
          NavigationDestination(
              icon: Icon(Icons.image_outlined),
              selectedIcon: Icon(Icons.image),
              label: 'Images'),
          NavigationDestination(
              icon: Icon(Icons.ios_share_outlined),
              selectedIcon: Icon(Icons.ios_share),
              label: 'Export'),
        ],
      ),
    );
  }
}
