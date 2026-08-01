import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/project_service.dart';
import '../models/renpy_project.dart';
import 'project_workspace_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _createProject(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Ren\'Py Project'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Moonlit Café'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!context.mounted) return;
    final project =
        await context.read<ProjectService>().createProject(name);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectWorkspaceScreen(project: project),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProjectService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ren'Py Studio Mobile"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProject(context),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
      body: service.loading
          ? const Center(child: CircularProgressIndicator())
          : service.projects.isEmpty
              ? _EmptyState(onCreate: () => _createProject(context))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: service.projects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final RenPyProject project = service.projects[i];
                    return _ProjectCard(project: project);
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.theater_comedy_outlined,
                size: 72, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No projects yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Create your first Ren\'Py project to start writing scenes, '
              'importing art, and exporting a launcher-ready game folder.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('New Project'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final RenPyProject project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          child: const Icon(Icons.movie_creation_outlined),
        ),
        title: Text(project.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${project.scripts.length} script file(s) · '
          '${project.characters.length} character(s)',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              context.read<ProjectService>().deleteProject(project);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () {
          context.read<ProjectService>().setActive(project);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectWorkspaceScreen(project: project),
            ),
          );
        },
      ),
    );
  }
}
