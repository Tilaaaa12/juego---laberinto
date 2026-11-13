import 'dart:math';

import 'maze_generator.dart';
import 'pathfinding.dart';

enum EnemyState { patrol, chase, frozen, dead }

/// Definición de un tipo de enemigo (cada mundo tiene los suyos).
class EnemyType {
  const EnemyType({
    required this.name,
    required this.maxHp,
    required this.detectRange,
    required this.moveEveryTicks,
    required this.damage,
  });

  final String name;
  final int maxHp;

  /// Distancia máxima (en pasos de pasillo, no en línea recta) a la que detecta.
  final int detectRange;

  /// Cada cuántos ticks se mueve una casilla (más alto = más lento).
  final int moveEveryTicks;
  final int damage;
}

class Enemy {
  Enemy({
    required this.id,
    required this.type,
    required this.position,
    required this.patrol,
  }) : hp = type.maxHp;

  final int id;
  final EnemyType type;
  Cell position;
  final List<Cell> patrol;
  int patrolIndex = 0;
  int hp;
  EnemyState state = EnemyState.patrol;
  int frozenTicks = 0;
  int _moveCounter = 0;

  bool get isAlive => state != EnemyState.dead;

  void takeDamage(int amount) {
    if (!isAlive) return;
    hp = max(0, hp - amount);
    if (hp == 0) state = EnemyState.dead;
  }

  void freeze(int ticks) {
    if (!isAlive) return;
    frozenTicks = ticks;
    state = EnemyState.frozen;
  }

  /// Empuja al enemigo hasta [cells] casillas alejándose de [from], sin cruzar muros.
  void knockBack(Cell from, int cells, bool Function(Cell) passable) {
    if (!isAlive) return;
    final dx = (position.x - from.x).sign;
    final dy = (position.y - from.y).sign;
    if (dx == 0 && dy == 0) return;
    // Solo en línea recta cardinal.
    final dir = dx.abs() >= dy.abs() && dx != 0 ? Cell(dx, 0) : Cell(0, dy);
    for (var i = 0; i < cells; i++) {
      final next = Cell(position.x + dir.x, position.y + dir.y);
      if (!passable(next)) break;
      position = next;
    }
  }
}

class EnemyAI {
  /// Avanza un tick lógico. Los enemigos solo pisan celdas de [passable]
  /// y nunca entran en [occupied] (otros enemigos).
  static void step(
    Enemy enemy,
    Cell playerPosition,
    bool Function(Cell) passable, {
    bool playerHidden = false,
    Set<Cell> occupied = const {},
  }) {
    if (!enemy.isAlive) return;
    if (enemy.state == EnemyState.frozen) {
      enemy.frozenTicks--;
      if (enemy.frozenTicks <= 0) enemy.state = EnemyState.patrol;
      return;
    }

    enemy._moveCounter++;
    if (enemy._moveCounter < enemy.type.moveEveryTicks) return;
    enemy._moveCounter = 0;

    var chasing = false;
    if (!playerHidden) {
      final near = bfsDistances(
        enemy.position,
        passable,
        maxDistance: enemy.type.detectRange,
      );
      chasing = near.containsKey(playerPosition);
    }
    enemy.state = chasing ? EnemyState.chase : EnemyState.patrol;

    Cell? target;
    if (chasing) {
      target = playerPosition;
    } else if (enemy.patrol.isNotEmpty) {
      if (enemy.position == enemy.patrol[enemy.patrolIndex]) {
        enemy.patrolIndex = (enemy.patrolIndex + 1) % enemy.patrol.length;
      }
      target = enemy.patrol[enemy.patrolIndex];
    }
    if (target == null || target == enemy.position) return;

    final path = bfsPath(enemy.position, target, passable);
    if (path == null || path.length < 2) return;
    final next = path[1];
    if (occupied.contains(next)) return;
    enemy.position = next;
  }


  /// Casilla a la que debe moverse un enemigo en este turno: persigue al
  /// jugador si está dentro de [detectRange] pasos de pasillo (y fuera de
  /// [safeZone]); si no, patrulla o vuelve a su ronda. Nunca cruza muros.
  static Cell nextCell({
    required Cell current,
    required List<Cell> patrol,
    required Cell player,
    required bool Function(Cell) passable,
    required int detectRange,
    Set<Cell> safeZone = const {},
    Iterable<Cell> taken = const [],
  }) {
    final near = bfsDistances(current, passable, maxDistance: detectRange);
    if (near.containsKey(player) && !safeZone.contains(player)) {
      final path = bfsPath(current, player, passable);
      if (path != null && path.length > 1 && !taken.contains(path[1])) {
        return path[1];
      }
      return current;
    }
    if (patrol.isEmpty) return current;
    if (patrol.length >= 2) {
      if (current == patrol.first) return patrol.last;
      if (current == patrol.last) return patrol.first;
    }
    final back = bfsPath(current, patrol.first, passable);
    return back != null && back.length > 1 ? back[1] : current;
  }

  static bool touching(Enemy enemy, Cell playerPosition) =>
      enemy.isAlive && enemy.position == playerPosition;
}

class EnemySpawner {
  /// Coloca enemigos lejos del jugador, sobre suelo libre, con ronda de patrulla
  /// alcanzable. Los primeros enemigos custodian las llaves si las hay.
  static List<Enemy> spawn({
    required GeneratedMaze maze,
    required int count,
    required List<EnemyType> types,
    required int seed,
    int minDistanceFromStart = 8,
  }) {
    if (count <= 0 || types.isEmpty) return [];
    final random = Random(seed);
    bool floor(Cell c) => maze.isFloor(c) && !maze.doors.containsKey(c);
    final fromStart = bfsDistances(maze.start, floor);
    final forbidden = <Cell>{
      maze.start,
      maze.goal,
      ...maze.keys.values,
      ...maze.traps,
    };
    final taken = <Cell>{};
    final enemies = <Enemy>[];

    Enemy? make(int id, Cell home) {
      final reach = bfsDistances(home, floor, maxDistance: 8);
      final stops = reach.entries
          .where((e) => e.value >= 3 && !forbidden.contains(e.key))
          .map((e) => e.key)
          .toList();
      final patrol = stops.isEmpty
          ? <Cell>[home]
          : <Cell>[home, stops[random.nextInt(stops.length)]];
      return Enemy(
        id: id,
        type: types[min(id, types.length - 1) % types.length],
        position: home,
        patrol: patrol,
      );
    }

    // Guardianes de llave.
    final keyCells = maze.keys.values.toList();
    for (var i = 0; i < keyCells.length && enemies.length < count; i++) {
      final around = bfsDistances(keyCells[i], floor, maxDistance: 3)
          .entries
          .where((e) =>
              e.value >= 2 &&
              (fromStart[e.key] ?? 0) >= minDistanceFromStart &&
              !forbidden.contains(e.key) &&
              !taken.contains(e.key))
          .map((e) => e.key)
          .toList();
      if (around.isEmpty) continue;
      final home = around[random.nextInt(around.length)];
      taken.add(home);
      final enemy = make(enemies.length, home);
      if (enemy != null) {
        // La ronda de un guardián siempre pasa por la llave.
        enemy.patrol
          ..clear()
          ..addAll([home, keyCells[i]]);
        enemies.add(enemy);
      }
    }

    final free = fromStart.entries
        .where((e) =>
            e.value >= minDistanceFromStart &&
            !forbidden.contains(e.key) &&
            !taken.contains(e.key))
        .map((e) => e.key)
        .toList()
      ..shuffle(random);
    for (final cell in free) {
      if (enemies.length >= count) break;
      // Separación mínima entre enemigos para no bloquear pasillos.
      if (taken.any((t) => (t.x - cell.x).abs() + (t.y - cell.y).abs() < 4)) {
        continue;
      }
      taken.add(cell);
      final enemy = make(enemies.length, cell);
      if (enemy != null) enemies.add(enemy);
    }
    return enemies;
  }
}
