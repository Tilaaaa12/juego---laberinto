import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_laberinto/models/maze_level.dart';
import 'package:juego_laberinto/models/player_character.dart';
import 'package:juego_laberinto/screens/game_screen.dart';
import 'package:juego_laberinto/screens/home_screen.dart';
import 'package:juego_laberinto/screens/instructions_screen.dart';
import 'package:juego_laberinto/screens/levels_screen.dart';
import 'package:juego_laberinto/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const referenceSizes = <Size>[
  Size(320, 568),
  Size(360, 800),
  Size(390, 844),
  Size(430, 932),
  Size(600, 960),
  Size(768, 1024),
  Size(800, 360),
  Size(844, 390),
  Size(932, 430),
  Size(1024, 768),
  Size(1366, 768),
  Size(1920, 1080),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'maze.music_enabled': false,
      'maze.effects_enabled': false,
    });
  });

  testWidgets('menu keeps the author credit visible at reference sizes', (
    tester,
  ) async {
    for (final size in referenceSizes) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            isDarkMode: false,
            onThemeChanged: (_) {},
            onStart: (_, _, _) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final credit = find.text('ELABORADO POR: ING. BALLADARES');
      expect(credit, findsOneWidget, reason: 'Viewport $size');
      final rect = tester.getRect(credit);
      expect(rect.left, greaterThanOrEqualTo(0), reason: 'Viewport $size');
      expect(
        rect.right,
        lessThanOrEqualTo(size.width),
        reason: 'Viewport $size',
      );
      expect(rect.top, greaterThanOrEqualTo(0), reason: 'Viewport $size');
      expect(
        rect.bottom,
        lessThanOrEqualTo(size.height),
        reason: 'Viewport $size',
      );
      expect(tester.takeException(), isNull, reason: 'Viewport $size');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('instructions fit every reference viewport without overflow', (
    tester,
  ) async {
    for (final size in referenceSizes) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(key: ValueKey(size), home: const InstructionsScreen()),
      );
      await tester.pump();

      expect(
        find.text('INSTRUCCIONES DE JUEGO – MAZE ADVENTURE'),
        findsOneWidget,
        reason: 'Viewport $size',
      );
      await tester.scrollUntilVisible(
        find.text('REGRESAR AL MENÚ PRINCIPAL'),
        180,
      );
      expect(
        find.text('REGRESAR AL MENÚ PRINCIPAL'),
        findsOneWidget,
        reason: 'Viewport $size',
      );
      expect(tester.takeException(), isNull, reason: 'Viewport $size');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('instructions navigation returns to the main menu', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          isDarkMode: false,
          onThemeChanged: (_) {},
          onStart: (_, _, _) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final openInstructions = find.text('INSTRUCCIONES DE JUEGO');
    await tester.ensureVisible(openInstructions);
    await tester.tap(
      find.ancestor(
        of: openInstructions,
        matching: find.byType(OutlinedButton),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(InstructionsScreen), findsOneWidget);
    expect(
      find.text('INSTRUCCIONES DE JUEGO – MAZE ADVENTURE'),
      findsOneWidget,
    );

    final returnButton = find.text('REGRESAR AL MENÚ PRINCIPAL');
    await tester.scrollUntilVisible(
      returnButton,
      180,
      scrollable: find.descendant(
        of: find.byType(InstructionsScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(returnButton);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('MAZE ADVENTURE'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('game, level selection, and settings remain layout-safe', (
    tester,
  ) async {
    for (final size in referenceSizes) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: MazeGameScreen(
            difficulty: MazeLevel.values.first,
            playerName: 'Prueba',
            character: PlayerCharacter.chomper,
            onThemeChanged: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'Juego $size');

      await tester.pumpWidget(
        MaterialApp(home: LevelsScreen(onSelect: (_) {})),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'Niveles $size');

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(isDarkMode: false, onThemeChanged: (_) {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'Ajustes $size');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('game adapts to landscape without resetting its progress', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: MazeGameScreen(
          difficulty: MazeLevel.values.first,
          playerName: 'Prueba',
          character: PlayerCharacter.chomper,
          onThemeChanged: (_) {},
        ),
      ),
    );
    final path = MazeGrid.generate(MazeLevel.values.first).solutionPath;
    final firstStep = path[1];
    final direction = firstStep.x > 1
        ? 'Derecha'
        : firstStep.x < 1
        ? 'Izquierda'
        : firstStep.y > 1
        ? 'Abajo'
        : 'Arriba';
    final rollButton = find.text('LANZAR DADO');
    await tester.ensureVisible(rollButton);
    await tester.tap(rollButton);
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();
    final moveButton = find.byTooltip(direction);
    await tester.ensureVisible(moveButton);
    await tester.tap(moveButton);
    await tester.pump();
    expect(find.text('Movimientos 1'), findsOneWidget);

    tester.view.physicalSize = const Size(800, 360);
    await tester.pump();

    final landscapeBoard = tester.getRect(
      find.byKey(const ValueKey('maze-board')),
    );
    final controlsRect = tester.getRect(moveButton);
    expect(find.text('Movimientos 1'), findsOneWidget);
    expect(landscapeBoard.right, lessThan(controlsRect.left));
    expect(landscapeBoard.right, lessThan(800));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
