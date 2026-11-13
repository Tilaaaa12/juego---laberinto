import 'dart:math';

enum MazeDifficulty { easy, medium, hard, expert, extreme }

class MazeLevel {
  const MazeLevel({
    required this.difficulty,
    required this.title,
    required this.tagline,
    required this.description,
    required this.objective,
    required this.size,
    required this.seed,
    required this.coinCount,
    required this.obstacleCount,
    required this.enemyCount,
    required this.keyCount,
    required this.icon,
  });

  final MazeDifficulty difficulty;
  final String title;
  final String tagline;
  final String description;
  final String objective;
  final int size;
  final int seed;
  final int coinCount;
  final int obstacleCount;
  final int enemyCount;
  final int keyCount;
  final String icon;

  String get dimensions => '$size × $size';

  int get index => values.indexOf(this);

  bool get requiresKey => keyCount > 0;

  static const values = [
    MazeLevel(
      difficulty: MazeDifficulty.easy,
      title: 'Bosque encantado',
      tagline: 'Estrellas entre los árboles',
      description: 'Un bosque mágico con rocas y arbustos en el camino.',
      objective: 'Reúne estrellas y encuentra la salida del bosque.',
      size: 11,
      seed: 145,
      coinCount: 4,
      obstacleCount: 2,
      enemyCount: 1,
      keyCount: 0,
      icon: '🌲',
    ),
    MazeLevel(
      difficulty: MazeDifficulty.medium,
      title: 'Mansión del terror',
      tagline: 'Una aventura espeluznante',
      description: 'Busca la llave, esquiva fantasmas y enciende tu linterna.',
      objective: 'Encuentra la llave y escapa de la mansión.',
      size: 13,
      seed: 278,
      coinCount: 5,
      obstacleCount: 3,
      enemyCount: 2,
      keyCount: 1,
      icon: '🏚️',
    ),
    MazeLevel(
      difficulty: MazeDifficulty.hard,
      title: 'Templo de la jungla',
      tagline: 'Ruinas llenas de secretos',
      description: 'Rocas antiguas y guardianes custodian el tesoro.',
      objective: 'Cruza las ruinas, reúne estrellas y alcanza el tesoro.',
      size: 15,
      seed: 491,
      coinCount: 6,
      obstacleCount: 4,
      enemyCount: 2,
      keyCount: 0,
      icon: '🗿',
    ),
    MazeLevel(
      difficulty: MazeDifficulty.expert,
      title: 'Laboratorio futurista',
      tagline: 'Infiltración de alta tecnología',
      description: 'Evita robots patrulleros y bloques de seguridad.',
      objective: 'Desactiva la seguridad y encuentra la salida.',
      size: 17,
      seed: 672,
      coinCount: 7,
      obstacleCount: 5,
      enemyCount: 3,
      keyCount: 1,
      icon: '🤖',
    ),
    MazeLevel(
      difficulty: MazeDifficulty.extreme,
      title: 'Reino de lava',
      tagline: 'El desafío final te espera',
      description: 'Núcleos volcánicos, guardianes y caminos ardientes.',
      objective: 'Sobrevive al volcán y alcanza la salida.',
      size: 19,
      seed: 853,
      coinCount: 8,
      obstacleCount: 6,
      enemyCount: 3,
      keyCount: 0,
      icon: '🌋',
    ),
  ];
}

class MazeGrid {
  MazeGrid._({
    required this.size,
    required this.walls,
    required this.collectibles,
    required this.obstacles,
    required this.keys,
    required this.enemyPatrols,
    required this.solutionPath,
  });

  final int size;
  final List<List<bool>> walls;
  final Set<Point<int>> collectibles;
  final Set<Point<int>> obstacles;
  final Set<Point<int>> keys;
  final List<List<Point<int>>> enemyPatrols;
  final List<Point<int>> solutionPath;

  Point<int> get start => const Point(1, 1);
  Point<int> get goal => Point(size - 2, size - 2);

  bool isInside(Point<int> cell) =>
      cell.x >= 0 && cell.y >= 0 && cell.x < size && cell.y < size;

  bool isWalkable(Point<int> cell) =>
      isInside(cell) && !walls[cell.y][cell.x] && !obstacles.contains(cell);

  factory MazeGrid.generate(MazeLevel level) {
    final size = level.size;
    final random = Random(level.seed);
    final walls = List.generate(size, (_) => List.filled(size, true));
    final visited = List.generate(size, (_) => List.filled(size, false));
    final stack = <Point<int>>[const Point(1, 1)];
    walls[1][1] = false;
    visited[1][1] = true;

    const directions = [
      Point<int>(0, -2),
      Point<int>(2, 0),
      Point<int>(0, 2),
      Point<int>(-2, 0),
    ];
    while (stack.isNotEmpty) {
      final current = stack.last;
      final neighbors = <Point<int>>[];
      for (final direction in directions) {
        final next = Point(current.x + direction.x, current.y + direction.y);
        if (next.x > 0 &&
            next.y > 0 &&
            next.x < size - 1 &&
            next.y < size - 1 &&
            !visited[next.y][next.x]) {
          neighbors.add(next);
        }
      }
      if (neighbors.isEmpty) {
        stack.removeLast();
        continue;
      }
      final next = neighbors[random.nextInt(neighbors.length)];
      walls[(current.y + next.y) ~/ 2][(current.x + next.x) ~/ 2] = false;
      walls[next.y][next.x] = false;
      visited[next.y][next.x] = true;
      stack.add(next);
    }

    // Rutas alternativas: abre algunos muros entre dos pasillos (más en
    // dificultades altas). La ruta más corta se calcula después.
    final braidChance = 0.03 * (level.difficulty.index + 1);
    for (var y = 1; y < size - 1; y++) {
      for (var x = 1; x < size - 1; x++) {
        if (!walls[y][x]) continue;
        final horizontal = !walls[y][x - 1] &&
            !walls[y][x + 1] &&
            walls[y - 1][x] &&
            walls[y + 1][x];
        final vertical = !walls[y - 1][x] &&
            !walls[y + 1][x] &&
            walls[y][x - 1] &&
            walls[y][x + 1];
        if ((horizontal || vertical) && random.nextDouble() < braidChance) {
          walls[y][x] = false;
        }
      }
    }

    final goal = Point(size - 2, size - 2);
    final route = _findPath(walls, size, const Point(1, 1), goal);
    if (route.isEmpty) {
      throw StateError('No se generó una ruta para ${level.title}.');
    }
    final routeCells = route.toSet();
    final candidates = <Point<int>>[];
    for (var y = 1; y < size - 1; y++) {
      for (var x = 1; x < size - 1; x++) {
        final cell = Point(x, y);
        if (!walls[y][x] &&
            !routeCells.contains(cell) &&
            cell != const Point(1, 1) &&
            cell != goal) {
          candidates.add(cell);
        }
      }
    }
    candidates.shuffle(random);
    final obstacleCount = min(level.obstacleCount, candidates.length);
    final obstacles = candidates.take(obstacleCount).toSet();

    final freeCells = <Point<int>>[];
    for (var y = 1; y < size - 1; y++) {
      for (var x = 1; x < size - 1; x++) {
        final cell = Point(x, y);
        if (!walls[y][x] &&
            !obstacles.contains(cell) &&
            cell != const Point(1, 1) &&
            cell != goal) {
          freeCells.add(cell);
        }
      }
    }
    freeCells.shuffle(random);

    final keys = <Point<int>>{};
    if (level.keyCount > 0) {
      final routeKeyIndex = max(1, (route.length * 0.62).floor());
      keys.add(route[routeKeyIndex.clamp(1, route.length - 2)]);
    }
    final collectibles = freeCells
        .where((cell) => !keys.contains(cell))
        .take(level.coinCount)
        .toSet();
    final enemyPatrols = <List<Point<int>>>[];
    var patrolCursor = 0;
    while (enemyPatrols.length < level.enemyCount &&
        patrolCursor < candidates.length) {
      final cell = candidates[patrolCursor++];
      if (obstacles.contains(cell)) continue;
      final neighbors = _openNeighbors(
        walls,
        size,
        cell,
      ).where((neighbor) => !obstacles.contains(neighbor)).toList();
      if (neighbors.isNotEmpty) {
        enemyPatrols.add([cell, neighbors[random.nextInt(neighbors.length)]]);
      }
    }

    return MazeGrid._(
      size: size,
      walls: walls,
      collectibles: collectibles,
      obstacles: obstacles,
      keys: keys,
      enemyPatrols: enemyPatrols,
      solutionPath: route,
    );
  }

  bool hasValidRoute() =>
      _findPath(walls, size, start, goal, blocked: obstacles).isNotEmpty;

  bool hasKeyReachableRoute() {
    if (keys.isEmpty) return hasValidRoute();
    final route = _findPath(walls, size, start, goal, blocked: obstacles);
    final keyPosition = route.indexWhere(keys.contains);
    return keyPosition > 0 && keyPosition < route.length - 1;
  }

  static List<Point<int>> _findPath(
    List<List<bool>> walls,
    int size,
    Point<int> start,
    Point<int> goal, {
    Set<Point<int>> blocked = const {},
  }) {
    final pending = <Point<int>>[start];
    final previous = <Point<int>, Point<int>?>{start: null};
    const steps = [
      Point<int>(0, -1),
      Point<int>(1, 0),
      Point<int>(0, 1),
      Point<int>(-1, 0),
    ];
    while (pending.isNotEmpty) {
      final current = pending.removeAt(0);
      if (current == goal) {
        final path = <Point<int>>[];
        Point<int>? cell = goal;
        while (cell != null) {
          path.add(cell);
          cell = previous[cell];
        }
        return path.reversed.toList();
      }
      for (final step in steps) {
        final next = Point(current.x + step.x, current.y + step.y);
        if (next.x < 0 ||
            next.y < 0 ||
            next.x >= size ||
            next.y >= size ||
            walls[next.y][next.x] ||
            blocked.contains(next) ||
            previous.containsKey(next)) {
          continue;
        }
        previous[next] = current;
        pending.add(next);
      }
    }
    return const [];
  }

  static List<Point<int>> _openNeighbors(
    List<List<bool>> walls,
    int size,
    Point<int> cell,
  ) {
    const steps = [
      Point<int>(0, -1),
      Point<int>(1, 0),
      Point<int>(0, 1),
      Point<int>(-1, 0),
    ];
    return steps
        .map((step) => Point(cell.x + step.x, cell.y + step.y))
        .where(
          (neighbor) =>
              neighbor.x >= 0 &&
              neighbor.y >= 0 &&
              neighbor.x < size &&
              neighbor.y < size &&
              !walls[neighbor.y][neighbor.x],
        )
        .toList();
  }
}
