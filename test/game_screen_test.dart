import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_laberinto/models/maze_level.dart';
import 'package:juego_laberinto/models/player_character.dart';
import 'package:juego_laberinto/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'maze.music_enabled': false,
      'maze.effects_enabled': false,
    });
  });

  testWidgets('wall attempts do not count, walkable steps do', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MazeGameScreen(
          difficulty: MazeLevel.values.first,
          playerName: 'Estudiante',
          character: PlayerCharacter.penguin,
          onThemeChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('LANZAR DADO'));
    await tester.tap(find.text('LANZAR DADO'));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();

    final moveCount = find.byKey(const ValueKey('move-count'));
    expect(tester.widget<Text>(moveCount).data, 'Movimientos 0');
    await tester.ensureVisible(find.byTooltip('Derecha'));
    await tester.tap(find.byTooltip('Derecha'));
    await tester.pump();
    expect(tester.widget<Text>(moveCount).data, 'Movimientos 0');

    await tester.ensureVisible(find.byTooltip('Abajo'));
    await tester.tap(find.byTooltip('Abajo'));
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.widget<Text>(moveCount).data, 'Movimientos 1');
  });

  testWidgets('keyboard moves with WASD or arrows and space uses the power', (
    tester,
  ) async {
    final level = MazeLevel.values.first;
    await tester.pumpWidget(
      MaterialApp(
        home: MazeGameScreen(
          difficulty: level,
          playerName: 'Estudiante',
          character: PlayerCharacter.penguin,
          onThemeChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('LANZAR DADO'));
    await tester.tap(find.text('LANZAR DADO'));
    await tester.pump(const Duration(milliseconds: 750));

    final path = MazeGrid.generate(level).solutionPath;
    final deltaX = path[1].x - path[0].x;
    final deltaY = path[1].y - path[0].y;
    final directionKey = deltaX == 1
        ? LogicalKeyboardKey.keyD
        : deltaX == -1
        ? LogicalKeyboardKey.keyA
        : deltaY == 1
        ? LogicalKeyboardKey.arrowDown
        : LogicalKeyboardKey.arrowUp;
    await tester.sendKeyDownEvent(directionKey);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.sendKeyUpEvent(directionKey);
    await tester.pump();

    final moveCount = find.byKey(const ValueKey('move-count'));
    final keyboardMoves = int.parse(
      tester.widget<Text>(moveCount).data!.split(' ').last,
    );
    expect(keyboardMoves, greaterThanOrEqualTo(1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Energía 82/100'), findsOneWidget);
  });
}
