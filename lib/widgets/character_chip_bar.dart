import 'package:flutter/material.dart';
import '../models/character.dart';

class CharacterChipBar extends StatelessWidget {
  final List<Character> characters;
  final VoidCallback onAdd;

  const CharacterChipBar(
      {super.key, required this.characters, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          ...characters.map((c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Chip(
                  avatar: CircleAvatar(
                      backgroundColor: c.color, radius: 6),
                  label: Text('${c.displayName}'),
                  visualDensity: VisualDensity.compact,
                ),
              )),
          ActionChip(
            avatar: const Icon(Icons.person_add_alt_1, size: 16),
            label: const Text('Character'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
