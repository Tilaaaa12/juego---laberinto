import 'dart:collection';
import 'dart:math';

/// Celda de la cuadrícula del laberinto (x = columna, y = fila).
typedef Cell = Point<int>;

const List<Cell> cardinalDirections = [
  Point(0, -1),
  Point(1, 0),
  Point(0, 1),
  Point(-1, 0),
];

/// BFS: distancia en pasos desde [from] a cada celda alcanzable.
/// [passable] debe incluir la comprobación de límites del tablero.
Map<Cell, int> bfsDistances(
  Cell from,
  bool Function(Cell) passable, {
  int? maxDistance,
}) {
  final distances = <Cell, int>{from: 0};
  final queue = Queue<Cell>()..add(from);
  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    final d = distances[current]!;
    if (maxDistance != null && d >= maxDistance) continue;
    for (final dir in cardinalDirections) {
      final next = Cell(current.x + dir.x, current.y + dir.y);
      if (distances.containsKey(next) || !passable(next)) continue;
      distances[next] = d + 1;
      queue.add(next);
    }
  }
  return distances;
}

/// Camino más corto de [from] a [to] (ambos incluidos) o null si no existe.
List<Cell>? bfsPath(Cell from, Cell to, bool Function(Cell) passable) {
  if (from == to) return [from];
  final parent = <Cell, Cell>{};
  final visited = <Cell>{from};
  final queue = Queue<Cell>()..add(from);
  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    for (final dir in cardinalDirections) {
      final next = Cell(current.x + dir.x, current.y + dir.y);
      if (visited.contains(next) || !passable(next)) continue;
      visited.add(next);
      parent[next] = current;
      if (next == to) {
        final path = <Cell>[to];
        var node = to;
        while (parent.containsKey(node)) {
          node = parent[node]!;
          path.add(node);
        }
        return path.reversed.toList();
      }
      queue.add(next);
    }
  }
  return null;
}
