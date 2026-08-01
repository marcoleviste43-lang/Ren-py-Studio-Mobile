import 'package:flutter/material.dart';

/// Maps to a Ren'Py `define e = Character("Eileen", color="#c8ffc8")` line.
class Character {
  String id;
  String varName; // e.g. "e" -- the python identifier used in script
  String displayName; // e.g. "Eileen"
  Color color;
  String? imageTag; // base image tag used for `show` statements

  Character({
    required this.id,
    required this.varName,
    required this.displayName,
    this.color = Colors.white,
    this.imageTag,
  });

  /// Emits the Ren'Py `define` line for this character.
  String toRenPyDefine() {
    final hex =
        '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    return 'define $varName = Character("$displayName", color="$hex")';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'varName': varName,
        'displayName': displayName,
        'color': color.value,
        'imageTag': imageTag,
      };

  factory Character.fromJson(Map<String, dynamic> json) => Character(
        id: json['id'],
        varName: json['varName'],
        displayName: json['displayName'],
        color: Color(json['color'] ?? 0xFFFFFFFF),
        imageTag: json['imageTag'],
      );
}
