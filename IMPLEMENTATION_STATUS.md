# MAZE – Estado de implementación

Documento honesto: qué existe, qué está probado y qué falta.

## Hecho en esta entrega (motor nuevo, Dart puro, sin dependencias nuevas)
Código en `lib/game/engine/` con pruebas en `test/engine/maze_engine_test.dart`.

- `maze_generator.dart`: laberintos procedurales (backtracker + rutas alternativas),
  puertas con llave, trampas y **resolutor BFS con estado de llaves** (`isSolvable`).
- `pathfinding.dart`: BFS (distancias y caminos) reutilizado por enemigos y habilidades.
- `enemy.dart`: enemigos con patrulla, detección por distancia de pasillo, persecución,
  congelación, retroceso y muerte; spawner que evita al jugador y custodia llaves.
- `abilities.dart`: 8 habilidades (bola de fuego, espada, escudo, velocidad, invisibilidad,
  congelación, curación, teletransporte) con cooldown, duración, usos y soporte de pausa;
  efectos que respetan los muros.
- `worlds.dart`: 5 mundos x 5 niveles (11 a 21 casillas), enemigos por mundo,
  constructor de niveles validado, reglas de desbloqueo y habilidades por personaje.

## Integrado en el juego existente (cambios mínimos)
- `lib/screens/game_screen.dart` (`_advanceEnemies`): los enemigos ahora **persiguen** por los
  pasillos con BFS (alcance 4 + dificultad), respetan muros y obstáculos, no persiguen en la
  zona segura de inicio y vuelven a su ronda si pierden al jugador. Antes solo alternaban
  entre dos casillas. Lógica en `EnemyAI.nextCell` (testeada).
- `lib/models/maze_level.dart` (`MazeGrid.generate`): abre algunos muros para crear **rutas
  alternativas** (más en dificultades altas). La ruta de solución, llaves y obstáculos se
  calculan después, así que siguen siendo válidos.
- Estos cambios tampoco se han compilado ni ejecutado.

## Verificación realizada
- Port de la lógica del generador a Python: 1200 laberintos (tamaños 11/15/17/21, 2 llaves)
  resolubles, y las puertas bloquean la meta sin sus llaves. Esto valida el algoritmo,
  NO la sintaxis Dart.
- **No se ejecutó** `flutter pub get`, `dart format`, `flutter analyze` ni `flutter test`
  (el entorno de generación no tiene Flutter ni Dart). El código nuevo puede tener
  errores de compilación por corregir.

## Pendiente (no implementado)
- Usar los mundos/niveles del motor (`WorldCatalog`, `LevelBuilder`) en las pantallas: el juego
  sigue usando los 5 niveles originales (`MazeLevel`).
- Selector de mundos, niveles y personajes con las nuevas estadísticas; pantallas de
  derrota/pausa ampliadas; rediseño visual.
- Controles configurables (teclas), botones táctiles de habilidades, dado con tecla E
  conectado al motor, persistencia de mundos/controles.
- Música propia por mundo (`musicTrack` ya definido; faltan los archivos de audio) y
  efectos nuevos.
- Layout horizontal/vertical que conserve la partida al rotar.
- Obstáculos dinámicos (muros intermitentes, plataformas, portales, interruptores).
