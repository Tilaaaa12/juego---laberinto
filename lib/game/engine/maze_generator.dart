import 'dart:collection';
import 'dart:math';

import 'pathfinding.dart';

/// Laberinto procedural con puertas, llaves y trampas.
///
/// Las puertas bloquean el paso hasta recoger la llave con el mismo id.
/// Las trampas son peligrosas pero transitables.
class GeneratedMaze {
  GeneratedMaze({
    required this.size,
    required this.walls,
    required this.start,
    required this.goal,
    required this.doors,
    required this.keys,
    required this.traps,
    required this.solution,
  });

  final int size;
  final List<List<bool>> walls;
  final Cell start;
  final Cell goal;

  /// celda de la puerta -> id de la llave que la abre.
  final Map<Cell, int> doors;

  /// id de llave -> celda donde está.
  final Map<int, Cell> keys;
  final Set<Cell> traps;

  /// Camino principal inicio -> meta ignorando puertas.
  final List<Cell> solution;

  bool inside(Cell c) => c.x >= 0 && c.y >= 0 && c.x < size && c.y < size;

  bool isFloor(Cell c) => inside(c) && !walls[c.y][c.x];

  /// Transitable para el jugador con las llaves de [keyMask].
  bool isPassable(Cell c, int keyMask) {
    if (!isFloor(c)) return false;
    final door = doors[c];
    return door == null || (keyMask & (1 << door)) != 0;
  }

  /// Transitable para enemigos: suelo sin puertas cerradas.
  bool Function(Cell) passableWithOpenDoors(Set<Cell> openDoors) {
    return (Cell c) => isFloor(c) && (!doors.containsKey(c) || openDoors.contains(c));
  }

  int get keyCount => keys.length;

  /// Pasos mínimos para ganar (recogiendo llaves necesarias) o null si es imposible.
  int? solveLength() => MazeSolver.solve(this);

  bool get isSolvable => solveLength() != null;
}

/// Resolutor BFS sobre el estado (celda, llaves recogidas).
class MazeSolver {
  static int? solve(GeneratedMaze maze) {
    final keyBits = <Cell, int>{
      for (final entry in maze.keys.entries) entry.value: 1 << entry.key,
    };
    final maskCount = 1 << maze.keyCount;
    final n = maze.size;
    final dist = List<int>.filled(n * n * maskCount, -1);
    int index(Cell c, int mask) => (c.y * n + c.x) * maskCount + mask;

    final startMask = keyBits[maze.start] ?? 0;
    final queue = Queue<(Cell, int)>()..add((maze.start, startMask));
    dist[index(maze.start, startMask)] = 0;

    while (queue.isNotEmpty) {
      final (cell, mask) = queue.removeFirst();
      final d = dist[index(cell, mask)];
      if (cell == maze.goal) return d;
      for (final dir in cardinalDirections) {
        final next = Cell(cell.x + dir.x, cell.y + dir.y);
        if (!maze.isPassable(next, mask)) continue;
        final nextMask = mask | (keyBits[next] ?? 0);
        final i = index(next, nextMask);
        if (dist[i] != -1) continue;
        dist[i] = d + 1;
        queue.add((next, nextMask));
      }
    }
    return null;
  }
}

class MazeGenerator {
  /// Genera un laberinto de [size] x [size] (se fuerza a tamaño impar, mínimo 7).
  ///
  /// [braid] (0..1) abre muros extra para crear rutas alternativas.
  static GeneratedMaze generate({
    required int size,
    required int seed,
    int keyCount = 0,
    int trapCount = 0,
    double braid = 0.08,
  }) {
    final n = max(7, size.isEven ? size + 1 : size);
    final random = Random(seed);
    final walls = List.generate(n, (_) => List.filled(n, true));
    const start = Cell(1, 1);
    final goal = Cell(n - 2, n - 2);

    _carve(walls, n, random);
    _braid(walls, n, random, braid);

    bool floor(Cell c) =>
        c.x >= 0 && c.y >= 0 && c.x < n && c.y < n && !walls[c.y][c.x];

    final path = bfsPath(start, goal, floor)!;

    final doors = <Cell, int>{};
    final keys = <int, Cell>{};
    final lockCount = min(keyCount, max(0, (path.length - 2) ~/ 4));
    for (var i = 0; i < lockCount; i++) {
      final idx = (((i + 1) * (path.length - 1)) / (lockCount + 1)).round();
      final cell = path[min(max(idx, 1), path.length - 2)];
      doors[cell] = i;
    }

    final used = <Cell>{start, goal, ...doors.keys};
    for (var i = 0; i < lockCount; i++) {
      // Llave i: alcanzable abriendo solo las puertas anteriores.
      final reach = bfsDistances(
        start,
        (c) => floor(c) && (!doors.containsKey(c) || doors[c]! < i),
      );
      final candidates = reach.entries
          .where((e) => !used.contains(e.key))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (candidates.isEmpty) {
        // No hay sitio: se retira la puerta para no crear un nivel imposible.
        doors.removeWhere((_, id) => id >= i);
        break;
      }
      final top = max(1, candidates.length ~/ 4);
      final pick = candidates[random.nextInt(top)].key;
      keys[i] = pick;
      used.add(pick);
    }

    final onPath = path.toSet();
    final trapCandidates = <Cell>[
      for (var y = 1; y < n - 1; y++)
        for (var x = 1; x < n - 1; x++)
          if (!walls[y][x] &&
              !onPath.contains(Cell(x, y)) &&
              !used.contains(Cell(x, y)) &&
              (x + y) > 5)
            Cell(x, y),
    ]..shuffle(random);
    final traps = trapCandidates.take(trapCount).toSet();

    return GeneratedMaze(
      size: n,
      walls: walls,
      start: start,
      goal: goal,
      doors: doors,
      keys: keys,
      traps: traps,
      solution: path,
    );
  }

  static void _carve(List<List<bool>> walls, int n, Random random) {
    walls[1][1] = false;
    final stack = <Cell>[const Cell(1, 1)];
    while (stack.isNotEmpty) {
      final cur = stack.last;
      final options = <Cell>[
        for (final d in cardinalDirections)
          if (cur.x + d.x * 2 > 0 &&
              cur.y + d.y * 2 > 0 &&
              cur.x + d.x * 2 < n - 1 &&
              cur.y + d.y * 2 < n - 1 &&
              walls[cur.y + d.y * 2][cur.x + d.x * 2])
            d,
      ];
      if (options.isEmpty) {
        stack.removeLast();
        continue;
      }
      final d = options[random.nextInt(options.length)];
      walls[cur.y + d.y][cur.x + d.x] = false;
      walls[cur.y + d.y * 2][cur.x + d.x * 2] = false;
      stack.add(Cell(cur.x + d.x * 2, cur.y + d.y * 2));
    }
  }

  static void _braid(
    List<List<bool>> walls,
    int n,
    Random random,
    double chance,
  ) {
    if (chance <= 0) return;
    for (var y = 1; y < n - 1; y++) {
      for (var x = 1; x < n - 1; x++) {
        if (!walls[y][x]) continue;
        final horizontal = !walls[y][x - 1] &&
            !walls[y][x + 1] &&
            walls[y - 1][x] &&
            walls[y + 1][x];
        final vertical = !walls[y - 1][x] &&
            !walls[y + 1][x] &&
            walls[y][x - 1] &&
            walls[y][x + 1];
        if ((horizontal || vertical) && random.nextDouble() < chance) {
          walls[y][x] = false;
        }
      }
    }
  }
}
