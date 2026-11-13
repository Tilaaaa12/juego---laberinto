import 'package:flutter/material.dart';

import '../models/maze_level.dart';

class WorldTheme {
  const WorldTheme({
    required this.background,
    required this.surface,
    required this.wall,
    required this.floor,
    required this.floorAlternate,
    required this.accent,
    required this.secondary,
  });

  final Color background;
  final Color surface;
  final Color wall;
  final Color floor;
  final Color floorAlternate;
  final Color accent;
  final Color secondary;

  static WorldTheme forLevel(MazeLevel level, {bool darkMode = false}) {
    switch (level.difficulty) {
      case MazeDifficulty.easy:
        return const WorldTheme(
          background: Color(0xFFE9F4DF),
          surface: Color(0xFFF9FFF3),
          wall: Color(0xFF214C35),
          floor: Color(0xFFD8EAC6),
          floorAlternate: Color(0xFFCEE2B9),
          accent: Color(0xFF66A352),
          secondary: Color(0xFFF5C451),
        );
      case MazeDifficulty.medium:
        return WorldTheme(
          background: darkMode
              ? const Color(0xFF17111F)
              : const Color(0xFF241A31),
          surface: darkMode ? const Color(0xFF2C2037) : const Color(0xFF372542),
          wall: const Color(0xFF170E20),
          floor: const Color(0xFF49334F),
          floorAlternate: const Color(0xFF523950),
          accent: const Color(0xFFD36681),
          secondary: const Color(0xFFA991D5),
        );
      case MazeDifficulty.hard:
        return const WorldTheme(
          background: Color(0xFFE4E4C4),
          surface: Color(0xFFF8F4D8),
          wall: Color(0xFF5B492C),
          floor: Color(0xFFD6D1A5),
          floorAlternate: Color(0xFFC9C493),
          accent: Color(0xFF779444),
          secondary: Color(0xFFC47B3A),
        );
      case MazeDifficulty.expert:
        return const WorldTheme(
          background: Color(0xFFE1EAF7),
          surface: Color(0xFFF5FAFF),
          wall: Color(0xFF182A49),
          floor: Color(0xFFD1E6F2),
          floorAlternate: Color(0xFFC5DDEF),
          accent: Color(0xFF2A9BCA),
          secondary: Color(0xFF8A65D6),
        );
      case MazeDifficulty.extreme:
        return const WorldTheme(
          background: Color(0xFF381B1B),
          surface: Color(0xFF532923),
          wall: Color(0xFF351B1A),
          floor: Color(0xFF71382B),
          floorAlternate: Color(0xFF85402B),
          accent: Color(0xFFF36A36),
          secondary: Color(0xFFFFC14D),
        );
    }
  }
}
