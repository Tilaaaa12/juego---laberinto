import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_laberinto/models/maze_level.dart';
import 'package:juego_laberinto/models/player_character.dart';
import 'package:juego_laberinto/screens/home_screen.dart';
import 'package:juego_laberinto/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'maze.music_enabled': false,
      'maze.effects_enabled': false,
    });
  });

  testWidgets('selected character is saved and passed to the new game', (
    tester,
  ) async {
    PlayerCharacter? startedCharacter;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          isDarkMode: false,
          onThemeChanged: (_) {},
          onStart: (_, MazeLevel level, PlayerCharacter character) {
            startedCharacter = character;
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('SELECCIONA TU PERSONAJE'), findsOneWidget);
    for (final character in PlayerCharacter.values) {
      expect(find.text(character.displayName), findsOneWidget);
    }

    await tester.ensureVisible(find.text('Pingüi'));
    await tester.tap(find.text('Pingüi'));
    await tester.pump();
    await tester.ensureVisible(find.text('JUGAR'));
    await tester.tap(find.text('JUGAR'));
    await tester.pump();

    expect(startedCharacter, PlayerCharacter.penguin);
    expect(await StorageService.loadCharacter(), PlayerCharacter.penguin);
  });
}
