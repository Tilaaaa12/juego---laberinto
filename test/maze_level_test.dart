import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:juego_laberinto/models/maze_level.dart';

void main() {
  group('MazeGrid', () {
    for (final level in MazeLevel.values) {
      test('${level.title} maze has a safe route and its world challenges', () {
        final maze = MazeGrid.generate(level);

        expect(maze.size, level.size);
        expect(maze.isWalkable(maze.start), isTrue);
        expect(maze.isWalkable(maze.goal), isTrue);
        expect(maze.hasValidRoute(), isTrue);
        expect(maze.hasKeyReachableRoute(), isTrue);
        expect(maze.collectibles.length, level.coinCount);
        expect(maze.collectibles.every(maze.isWalkable), isTrue);
        expect(maze.collectibles, isNot(contains(maze.start)));
        expect(maze.collectibles, isNot(contains(maze.goal)));
        expect(maze.obstacles.length, level.obstacleCount);
        expect(
          maze.obstacles.every((cell) => !maze.solutionPath.contains(cell)),
          isTrue,
        );
        expect(maze.enemyPatrols, hasLength(level.enemyCount));
      });
    }

    test('walls and out-of-bounds cells cannot be traversed', () {
      final maze = MazeGrid.generate(MazeLevel.values.first);

      expect(maze.isWalkable(const Point(-1, 0)), isFalse);
      expect(maze.isWalkable(const Point(0, 0)), isFalse);
      expect(maze.isWalkable(const Point(mazeSize, 1)), isFalse);
    });

    test('all five worlds generate different maze layouts', () {
      final layouts = MazeLevel.values.map((level) {
        final maze = MazeGrid.generate(level);
        return maze.walls
            .map((row) => row.map((wall) => wall ? '#' : '.').join())
            .join('\n');
      }).toSet();

      expect(layouts, hasLength(MazeLevel.values.length));
    });
  });
}

const mazeSize = 11;
