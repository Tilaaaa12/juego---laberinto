import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:juego_laberinto/game/engine/abilities.dart';
import 'package:juego_laberinto/game/engine/enemy.dart';
import 'package:juego_laberinto/game/engine/maze_generator.dart';
import 'package:juego_laberinto/game/engine/pathfinding.dart';
import 'package:juego_laberinto/game/engine/worlds.dart';
import 'package:juego_laberinto/models/player_character.dart';

String _layout(GeneratedMaze m) => m.walls
    .map((row) => row.map((w) => w ? '#' : '.').join())
    .join('\n');

void main() {
  group('MazeGenerator', () {
    test('sizes 11, 15 and 21 are solvable with start/goal on floor', () {
      for (final size in [11, 15, 21]) {
        for (var seed = 0; seed < 25; seed++) {
          final maze = MazeGenerator.generate(
            size: size,
            seed: seed,
            keyCount: 2,
            trapCount: 5,
            braid: 0.1,
          );
          expect(maze.size, size);
          expect(maze.isFloor(maze.start), isTrue);
          expect(maze.isFloor(maze.goal), isTrue);
          expect(maze.isSolvable, isTrue, reason: 'size $size seed $seed');
        }
      }
    });

    test('border is always wall', () {
      final maze = MazeGenerator.generate(size: 15, seed: 3, braid: 0.5);
      for (var i = 0; i < maze.size; i++) {
        expect(maze.walls[0][i], isTrue);
        expect(maze.walls[maze.size - 1][i], isTrue);
        expect(maze.walls[i][0], isTrue);
        expect(maze.walls[i][maze.size - 1], isTrue);
      }
    });

    test('even sizes are rounded up to odd', () {
      expect(MazeGenerator.generate(size: 10, seed: 1).size, 11);
    });

    test('same seed gives same maze, different seeds differ', () {
      final a = MazeGenerator.generate(size: 15, seed: 5);
      final b = MazeGenerator.generate(size: 15, seed: 5);
      final c = MazeGenerator.generate(size: 15, seed: 6);
      expect(_layout(a), _layout(b));
      expect(_layout(a), isNot(_layout(c)));
    });

    test('maze has dead ends and branching', () {
      final maze = MazeGenerator.generate(size: 21, seed: 9, braid: 0);
      var deadEnds = 0;
      var junctions = 0;
      for (var y = 1; y < maze.size - 1; y++) {
        for (var x = 1; x < maze.size - 1; x++) {
          final c = Cell(x, y);
          if (!maze.isFloor(c)) continue;
          final open = cardinalDirections
              .where((d) => maze.isFloor(Cell(x + d.x, y + d.y)))
              .length;
          if (open == 1) deadEnds++;
          if (open >= 3) junctions++;
        }
      }
      expect(deadEnds, greaterThan(3));
      expect(junctions, greaterThan(3));
    });

    test('braiding adds alternative routes (fewer walls)', () {
      int wallCount(GeneratedMaze m) =>
          m.walls.expand((r) => r).where((w) => w).length;
      final perfect = MazeGenerator.generate(size: 21, seed: 4, braid: 0);
      final loopy = MazeGenerator.generate(size: 21, seed: 4, braid: 0.3);
      expect(wallCount(loopy), lessThan(wallCount(perfect)));
    });

    test('doors block the way until the key is collected', () {
      for (var seed = 0; seed < 25; seed++) {
        final maze = MazeGenerator.generate(
          size: 17,
          seed: seed,
          keyCount: 2,
          braid: 0,
        );
        expect(maze.doors, isNotEmpty);
        expect(maze.keys.length, maze.doors.length);
        // Sin llaves no se puede llegar a la meta (laberinto perfecto).
        final noKeys = bfsPath(
          maze.start,
          maze.goal,
          (c) => maze.isPassable(c, 0),
        );
        expect(noKeys, isNull, reason: 'seed $seed');
        // Con todas las llaves sí.
        final allKeys = bfsPath(
          maze.start,
          maze.goal,
          (c) => maze.isPassable(c, (1 << maze.keyCount) - 1),
        );
        expect(allKeys, isNotNull);
        expect(maze.isSolvable, isTrue);
      }
    });

    test('keys and doors never sit on start or goal', () {
      final maze = MazeGenerator.generate(size: 17, seed: 2, keyCount: 2);
      final special = [...maze.doors.keys, ...maze.keys.values];
      expect(special, isNot(contains(maze.start)));
      expect(special, isNot(contains(maze.goal)));
      expect(special.toSet().length, special.length);
    });

    test('traps are on floor and off the main route', () {
      final maze = MazeGenerator.generate(size: 15, seed: 8, trapCount: 6);
      expect(maze.traps, isNotEmpty);
      for (final t in maze.traps) {
        expect(maze.isFloor(t), isTrue);
        expect(maze.solution, isNot(contains(t)));
      }
    });
  });

  group('Pathfinding', () {
    test('BFS never crosses walls', () {
      final maze = MazeGenerator.generate(size: 15, seed: 12);
      final path = bfsPath(maze.start, maze.goal, maze.isFloor)!;
      expect(path.first, maze.start);
      expect(path.last, maze.goal);
      expect(path.every(maze.isFloor), isTrue);
      for (var i = 1; i < path.length; i++) {
        final d = (path[i].x - path[i - 1].x).abs() +
            (path[i].y - path[i - 1].y).abs();
        expect(d, 1);
      }
    });
  });

  group('Enemies', () {
    const type = EnemyType(
      name: 'test',
      maxHp: 3,
      detectRange: 8,
      moveEveryTicks: 1,
      damage: 1,
    );

    test('enemies never leave the corridors and never stand on the player start',
        () {
      for (var seed = 0; seed < 10; seed++) {
        final maze = MazeGenerator.generate(size: 15, seed: seed, keyCount: 1);
        final enemies = EnemySpawner.spawn(
          maze: maze,
          count: 3,
          types: const [type],
          seed: seed,
        );
        for (final e in enemies) {
          expect(maze.isFloor(e.position), isTrue);
          expect(e.position, isNot(maze.start));
        }
        final passable = maze.passableWithOpenDoors({});
        final random = Random(seed);
        var player = maze.start;
        for (var tick = 0; tick < 200; tick++) {
          final dir = cardinalDirections[random.nextInt(4)];
          final next = Cell(player.x + dir.x, player.y + dir.y);
          if (maze.isFloor(next) && !maze.doors.containsKey(next)) player = next;
          for (final e in enemies) {
            EnemyAI.step(e, player, passable);
            expect(maze.isFloor(e.position), isTrue,
                reason: 'enemy entered a wall');
            expect(maze.doors.containsKey(e.position), isFalse);
          }
        }
      }
    });

    test('enemy chases a nearby player and stops when player hides', () {
      final maze = MazeGenerator.generate(size: 11, seed: 1);
      final path = bfsPath(maze.start, maze.goal, maze.isFloor)!;
      final enemy = Enemy(id: 0, type: type, position: path[6], patrol: [path[6]]);
      final player = path[2];
      final before = bfsPath(enemy.position, player, maze.isFloor)!.length;
      EnemyAI.step(enemy, player, maze.isFloor);
      expect(enemy.state, EnemyState.chase);
      final after = bfsPath(enemy.position, player, maze.isFloor)!.length;
      expect(after, lessThan(before));

      EnemyAI.step(enemy, player, maze.isFloor, playerHidden: true);
      expect(enemy.state, EnemyState.patrol);
    });

    test('damage kills, frozen enemies do not move', () {
      final e = Enemy(
        id: 1,
        type: type,
        position: const Cell(1, 1),
        patrol: const [Cell(1, 1)],
      );
      e.freeze(3);
      EnemyAI.step(e, const Cell(1, 2), (c) => true);
      expect(e.position, const Cell(1, 1));
      e.takeDamage(2);
      expect(e.isAlive, isTrue);
      e.takeDamage(5);
      expect(e.isAlive, isFalse);
      expect(e.hp, 0);
    });
  });


  group('EnemyAI.nextCell (used by the game screen)', () {
    test('chases through corridors, never into walls', () {
      final maze = MazeGenerator.generate(size: 15, seed: 21, braid: 0);
      final path = bfsPath(maze.start, maze.goal, maze.isFloor)!;
      var enemy = path[10];
      final player = path[6];
      for (var i = 0; i < 4; i++) {
        final next = EnemyAI.nextCell(
          current: enemy,
          patrol: [enemy],
          player: player,
          passable: maze.isFloor,
          detectRange: 8,
        );
        expect(maze.isFloor(next), isTrue);
        expect(
          (next.x - enemy.x).abs() + (next.y - enemy.y).abs() <= 1,
          isTrue,
        );
        enemy = next;
      }
      expect(enemy, player);
    });

    test('ignores a player inside the safe zone', () {
      final maze = MazeGenerator.generate(size: 11, seed: 2, braid: 0);
      final path = bfsPath(maze.start, maze.goal, maze.isFloor)!;
      final next = EnemyAI.nextCell(
        current: path[3],
        patrol: [path[3], path[4]],
        player: path[1],
        passable: maze.isFloor,
        detectRange: 8,
        safeZone: {path[1]},
      );
      expect(next, path[4]); // patrulla en lugar de perseguir
    });

    test('returns to patrol when the player is out of range', () {
      final maze = MazeGenerator.generate(size: 15, seed: 5, braid: 0);
      final path = bfsPath(maze.start, maze.goal, maze.isFloor)!;
      final next = EnemyAI.nextCell(
        current: path[5],
        patrol: [path[2], path[3]],
        player: maze.goal,
        passable: maze.isFloor,
        detectRange: 2,
      );
      expect(next, path[4]); // un paso hacia su ronda
    });
  });

  group('Abilities', () {
    test('cooldown, duration and limited uses', () {
      final c = AbilityController([AbilityKind.shield, AbilityKind.heal]);
      expect(c.activate(AbilityKind.shield, 0), isTrue);
      expect(c.isActive(AbilityKind.shield, 1000), isTrue);
      expect(c.isActive(AbilityKind.shield, 3000), isFalse);
      expect(c.canUse(AbilityKind.shield, 5000), isFalse);
      expect(c.canUse(AbilityKind.shield, 9000), isTrue);

      expect(c.activate(AbilityKind.heal, 0), isTrue);
      expect(c.activate(AbilityKind.heal, 20000), isTrue);
      expect(c.activate(AbilityKind.heal, 60000), isFalse);
      expect(c.usesLeft(AbilityKind.heal), 0);
    });

    test('abilities outside the loadout cannot be used', () {
      final c = AbilityController([AbilityKind.sword]);
      expect(c.canUse(AbilityKind.fireball, 0), isFalse);
    });

    test('pause shifts timers so cooldowns do not elapse while paused', () {
      final c = AbilityController([AbilityKind.shield]);
      c.activate(AbilityKind.shield, 0);
      c.shift(5000);
      expect(c.isActive(AbilityKind.shield, 5500), isTrue);
      expect(c.cooldownRemaining(AbilityKind.shield, 5000), 9000);
    });

    test('fireball hits the first enemy and is stopped by walls', () {
      final maze = MazeGenerator.generate(size: 11, seed: 1, braid: 0);
      // Pasillo recto: buscamos 3 celdas seguidas en horizontal.
      Cell? origin;
      for (var y = 1; y < maze.size - 1 && origin == null; y++) {
        for (var x = 1; x < maze.size - 4; x++) {
          if ([0, 1, 2, 3].every((i) => maze.isFloor(Cell(x + i, y)))) {
            origin = Cell(x, y);
            break;
          }
        }
      }
      expect(origin, isNotNull);
      final o = origin!;
      const type = EnemyType(
        name: 't', maxHp: 2, detectRange: 3, moveEveryTicks: 1, damage: 1);
      final enemy = Enemy(
        id: 0,
        type: type,
        position: Cell(o.x + 2, o.y),
        patrol: const [],
      );
      final hit = AbilityEffects.fireProjectile(
        origin: o,
        direction: const Cell(1, 0),
        enemies: [enemy],
        passable: maze.isFloor,
        range: 6,
        damage: 2,
      );
      expect(hit, same(enemy));
      expect(enemy.isAlive, isFalse);

      // Hacia un muro: no alcanza nada.
      final wallDir = cardinalDirections.firstWhere(
        (d) => !maze.isFloor(Cell(o.x + d.x, o.y + d.y)),
      );
      final other = Enemy(
        id: 1,
        type: type,
        position: Cell(o.x + wallDir.x * 2, o.y + wallDir.y * 2),
        patrol: const [],
      );
      final miss = AbilityEffects.fireProjectile(
        origin: o,
        direction: wallDir,
        enemies: [other],
        passable: maze.isFloor,
        range: 6,
        damage: 2,
      );
      expect(miss, isNull);
      expect(other.hp, 2);
    });

    test('teleport stops at walls', () {
      final maze = MazeGenerator.generate(size: 11, seed: 1);
      for (final d in cardinalDirections) {
        final target = AbilityEffects.teleportTarget(
          origin: maze.start,
          direction: d,
          passable: maze.isFloor,
          range: 3,
        );
        expect(maze.isFloor(target), isTrue);
      }
    });

    test('sword does not hit through walls', () {
      final maze = MazeGenerator.generate(size: 11, seed: 1, braid: 0);
      const type = EnemyType(
        name: 't', maxHp: 3, detectRange: 3, moveEveryTicks: 1, damage: 1);
      // Celda vecina en línea recta pero separada por muro: distancia de pasillo > 1.
      final origin = maze.start;
      Cell? behindWall;
      for (final d in cardinalDirections) {
        final wall = Cell(origin.x + d.x, origin.y + d.y);
        final beyond = Cell(origin.x + d.x * 2, origin.y + d.y * 2);
        if (!maze.isFloor(wall) && maze.isFloor(beyond)) behindWall = beyond;
      }
      if (behindWall == null) return; // sin caso útil con esta semilla
      final e = Enemy(id: 0, type: type, position: behindWall, patrol: const []);
      final hit = AbilityEffects.swordSwing(
        origin: origin,
        enemies: [e],
        passable: maze.isFloor,
        range: 1,
        damage: 3,
      );
      expect(hit, isEmpty);
      expect(e.isAlive, isTrue);
    });
  });

  group('Worlds', () {
    test('there are five worlds with five levels each and unique ids', () {
      expect(WorldCatalog.worlds, hasLength(5));
      expect(WorldCatalog.worlds.map((w) => w.id).toSet(), hasLength(5));
      for (final w in WorldCatalog.worlds) {
        expect(w.levelCount, 5);
        expect(w.enemyTypes, isNotEmpty);
      }
    });

    test('difficulty grows inside each world', () {
      for (final w in WorldCatalog.worlds) {
        for (var i = 1; i < w.levelCount; i++) {
          expect(w.levels[i].size, greaterThanOrEqualTo(w.levels[i - 1].size));
          expect(w.levels[i].enemies,
              greaterThanOrEqualTo(w.levels[i - 1].enemies));
        }
        expect(w.levels.first.size, 11);
        expect(w.levels.last.size, greaterThanOrEqualTo(21));
      }
    });

    test('every level of every world builds, is solvable and playable', () {
      final layouts = <String>{};
      for (final w in WorldCatalog.worlds) {
        for (var i = 0; i < w.levelCount; i++) {
          final spec = w.levels[i];
          final built = LevelBuilder.build(w, i);
          final maze = built.maze;
          expect(maze.isSolvable, isTrue, reason: '${w.id}/$i');
          expect(maze.keyCount, spec.keys, reason: '${w.id}/$i');
          expect(built.enemies, hasLength(spec.enemies));
          for (final e in built.enemies) {
            expect(maze.isFloor(e.position), isTrue);
            expect(e.position, isNot(maze.start));
          }
          layouts.add(_layout(maze));
        }
      }
      expect(layouts, hasLength(25));
    });

    test('progression unlocks levels in order and worlds after 3 levels', () {
      final first = WorldCatalog.worlds[0];
      expect(ProgressionRules.isLevelUnlocked(0, 0, {}), isTrue);
      expect(ProgressionRules.isLevelUnlocked(0, 1, {}), isFalse);
      expect(ProgressionRules.isWorldUnlocked(1, {}), isFalse);
      final done = {for (var i = 0; i < 3; i++) '${first.id}:$i'};
      expect(ProgressionRules.isLevelUnlocked(0, 3, done), isTrue);
      expect(ProgressionRules.isWorldUnlocked(1, done), isTrue);
      expect(ProgressionRules.isWorldUnlocked(2, done), isFalse);
    });
  });

  group('Characters', () {
    test('each character has a different ability loadout', () {
      final loadouts = {
        for (final c in PlayerCharacter.values)
          c: CharacterLoadout.of(c).abilities.map((a) => a.name).join('+'),
      };
      expect(loadouts.values.toSet(), hasLength(PlayerCharacter.values.length));
      for (final c in PlayerCharacter.values) {
        for (final kind in CharacterLoadout.of(c).abilities) {
          expect(abilityCatalog.containsKey(kind), isTrue);
        }
      }
    });
  });
}
