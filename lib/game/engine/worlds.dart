import 'package:juego_laberinto/models/player_character.dart';

import 'abilities.dart';
import 'enemy.dart';
import 'maze_generator.dart';

/// Parámetros de un nivel dentro de un mundo.
class LevelSpec {
  const LevelSpec({
    required this.title,
    required this.size,
    required this.keys,
    required this.enemies,
    required this.traps,
    required this.braid,
  });

  final String title;
  final int size;
  final int keys;
  final int enemies;
  final int traps;
  final double braid;
}

/// Un universo temático: identidad, enemigos, trampas y niveles propios.
/// Para añadir un mundo nuevo basta con agregar otra entrada a [WorldCatalog].
class WorldDef {
  const WorldDef({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.musicTrack,
    required this.enemyTypes,
    required this.trapNames,
    required this.keyName,
    required this.doorName,
    required this.levels,
    required this.seed,
  });

  final String id;
  final String name;
  final String tagline;
  final String description;
  final int primaryColor;
  final int secondaryColor;

  /// Nombre de la pista de música (archivo en assets/audio sin extensión).
  final String musicTrack;
  final List<EnemyType> enemyTypes;
  final List<String> trapNames;
  final String keyName;
  final String doorName;
  final List<LevelSpec> levels;
  final int seed;

  int get levelCount => levels.length;
}

LevelSpec _spec(String title, int tier) {
  const sizes = [11, 13, 15, 17, 21];
  const keys = [0, 1, 1, 2, 2];
  const enemies = [1, 2, 3, 4, 5];
  const traps = [2, 3, 5, 7, 9];
  const braids = [0.04, 0.06, 0.08, 0.10, 0.14];
  return LevelSpec(
    title: title,
    size: sizes[tier],
    keys: keys[tier],
    enemies: enemies[tier],
    traps: traps[tier],
    braid: braids[tier],
  );
}

List<LevelSpec> _levels(List<String> titles) => [
  for (var i = 0; i < titles.length; i++) _spec(titles[i], i),
];

class WorldCatalog {
  static final List<WorldDef> worlds = [
    WorldDef(
      id: 'terror',
      name: 'Terror y Supervivencia',
      tagline: 'No hagas ruido',
      description:
          'Pasillos de un hospital abandonado en penumbra. Busca llaves, '
          'abre puertas y evita a lo que acecha.',
      primaryColor: 0xFF8B1E2D,
      secondaryColor: 0xFF1B1B24,
      musicTrack: 'world_terror',
      enemyTypes: const [
        EnemyType(name: 'Acechador', maxHp: 3, detectRange: 7, moveEveryTicks: 3, damage: 1),
        EnemyType(name: 'Guardián de ala', maxHp: 5, detectRange: 5, moveEveryTicks: 4, damage: 1),
        EnemyType(name: 'Criatura del ruido', maxHp: 4, detectRange: 9, moveEveryTicks: 2, damage: 1),
      ],
      trapNames: const ['Suelo podrido', 'Cables sueltos'],
      keyName: 'Llave oxidada',
      doorName: 'Puerta bloqueada',
      levels: _levels([
        'Recepción',
        'Pasillo de urgencias',
        'Quirófano',
        'Sótano',
        'Morgue',
      ]),
      seed: 11,
    ),
    WorldDef(
      id: 'mitologia',
      name: 'Mitología e Historia Antigua',
      tagline: 'Los dioses vigilan',
      description:
          'Templos de Grecia, Egipto, Roma y el norte. Esquiva trampas '
          'antiguas y a los guardianes de piedra.',
      primaryColor: 0xFFC9A227,
      secondaryColor: 0xFF3E2F1C,
      musicTrack: 'world_mitologia',
      enemyTypes: const [
        EnemyType(name: 'Estatua animada', maxHp: 5, detectRange: 4, moveEveryTicks: 4, damage: 1),
        EnemyType(name: 'Guardián mitológico', maxHp: 4, detectRange: 6, moveEveryTicks: 3, damage: 1),
        EnemyType(name: 'Criatura antigua', maxHp: 3, detectRange: 8, moveEveryTicks: 2, damage: 1),
      ],
      trapNames: const ['Pinchos de bronce', 'Losa que cae'],
      keyName: 'Llave antigua',
      doorName: 'Puerta de piedra',
      levels: _levels([
        'Templo de Atenea',
        'Pirámide menor',
        'Foro en ruinas',
        'Salón de Valhalla',
        'Cámara del Faraón',
      ]),
      seed: 23,
    ),
    WorldDef(
      id: 'digital',
      name: 'Red Digital',
      tagline: 'Ejecutando...',
      description:
          'Dentro de un servidor: circuitos neón, cortafuegos y programas '
          'antivirus que te persiguen.',
      primaryColor: 0xFF00E5FF,
      secondaryColor: 0xFF0A1330,
      musicTrack: 'world_digital',
      enemyTypes: const [
        EnemyType(name: 'Virus', maxHp: 2, detectRange: 8, moveEveryTicks: 2, damage: 1),
        EnemyType(name: 'Antivirus', maxHp: 4, detectRange: 7, moveEveryTicks: 3, damage: 1),
        EnemyType(name: 'Proceso hostil', maxHp: 3, detectRange: 6, moveEveryTicks: 2, damage: 1),
      ],
      trapNames: const ['Campo eléctrico', 'Cortafuegos'],
      keyName: 'Código de acceso',
      doorName: 'Bloqueo digital',
      levels: _levels([
        'Puerto de entrada',
        'Placa base',
        'Granja de servidores',
        'Núcleo del procesador',
        'Sala del mainframe',
      ]),
      seed: 37,
    ),
    WorldDef(
      id: 'fantasia',
      name: 'Fantasía y Magia',
      tagline: 'Hay magia en el aire',
      description:
          'Bosques encantados, cuevas de cristal y castillos. Runas, '
          'portales y criaturas guardianas.',
      primaryColor: 0xFF8E5CF7,
      secondaryColor: 0xFF1E3A2F,
      musicTrack: 'world_fantasia',
      enemyTypes: const [
        EnemyType(name: 'Duendecillo', maxHp: 2, detectRange: 7, moveEveryTicks: 2, damage: 1),
        EnemyType(name: 'Troll de cueva', maxHp: 6, detectRange: 5, moveEveryTicks: 4, damage: 1),
        EnemyType(name: 'Dragón joven', maxHp: 5, detectRange: 8, moveEveryTicks: 3, damage: 1),
      ],
      trapNames: const ['Campo mágico', 'Barrera elemental'],
      keyName: 'Llave mágica',
      doorName: 'Puerta encantada',
      levels: _levels([
        'Bosque encantado',
        'Cueva de cristal',
        'Templo de runas',
        'Reino de los portales',
        'Castillo del dragón',
      ]),
      seed: 41,
    ),
    WorldDef(
      id: 'espacial',
      name: 'Espacial y Tripulación',
      tagline: 'Alguien no es quien dice ser',
      description:
          'Una nave a la deriva. Repara sistemas, consigue tarjetas de '
          'acceso y evita robots y adversarios.',
      primaryColor: 0xFF3FA7FF,
      secondaryColor: 0xFF0B0F1E,
      musicTrack: 'world_espacial',
      enemyTypes: const [
        EnemyType(name: 'Robot vigía', maxHp: 4, detectRange: 6, moveEveryTicks: 3, damage: 1),
        EnemyType(name: 'Tripulante adversario', maxHp: 3, detectRange: 8, moveEveryTicks: 2, damage: 1),
        EnemyType(name: 'Dron de seguridad', maxHp: 5, detectRange: 7, moveEveryTicks: 3, damage: 1),
      ],
      trapNames: const ['Campo láser', 'Fuga de plasma'],
      keyName: 'Tarjeta de acceso',
      doorName: 'Puerta automática',
      levels: _levels([
        'Muelle de carga',
        'Laboratorio',
        'Conductos',
        'Sala de control',
        'Núcleo del reactor',
      ]),
      seed: 53,
    ),
  ];
}

/// Nivel listo para jugar: laberinto ya validado y enemigos colocados.
class BuiltLevel {
  const BuiltLevel({required this.maze, required this.enemies, required this.seed});

  final GeneratedMaze maze;
  final List<Enemy> enemies;
  final int seed;
}

class LevelBuilder {
  /// Construye y VALIDA un nivel. Si una semilla no cumple las condiciones
  /// (solucionable, enemigos suficientes) prueba otra, de forma determinista.
  static BuiltLevel build(WorldDef world, int levelIndex) {
    final spec = world.levels[levelIndex];
    for (var attempt = 0; attempt < 30; attempt++) {
      final seed = world.seed * 1000 + levelIndex * 97 + attempt * 7919;
      final maze = MazeGenerator.generate(
        size: spec.size,
        seed: seed,
        keyCount: spec.keys,
        trapCount: spec.traps,
        braid: spec.braid,
      );
      if (!maze.isSolvable) continue;
      if (maze.keyCount < spec.keys) continue;
      final enemies = EnemySpawner.spawn(
        maze: maze,
        count: spec.enemies,
        types: _typesForTier(world, levelIndex),
        seed: seed + 1,
      );
      if (enemies.length < spec.enemies) continue;
      return BuiltLevel(maze: maze, enemies: enemies, seed: seed);
    }
    throw StateError('No se pudo generar un nivel válido: ${world.id}/$levelIndex');
  }

  /// Los niveles bajos usan solo los enemigos más suaves; la variedad crece.
  static List<EnemyType> _typesForTier(WorldDef world, int levelIndex) {
    final wanted = 1 + levelIndex ~/ 2;
    final count = wanted > world.enemyTypes.length ? world.enemyTypes.length : wanted;
    return world.enemyTypes.take(count).toList();
  }
}

/// Reglas de desbloqueo: niveles en orden; un mundo se abre al completar
/// al menos [levelsToUnlockNext] niveles del anterior.
class ProgressionRules {
  static const int levelsToUnlockNext = 3;

  static String levelKey(String worldId, int levelIndex) => '$worldId:$levelIndex';

  static bool isWorldUnlocked(int worldIndex, Set<String> completed) {
    if (worldIndex <= 0) return true;
    final previous = WorldCatalog.worlds[worldIndex - 1];
    final done = [
      for (var i = 0; i < previous.levelCount; i++)
        if (completed.contains(levelKey(previous.id, i))) i,
    ].length;
    return done >= levelsToUnlockNext && isWorldUnlocked(worldIndex - 1, completed);
  }

  static bool isLevelUnlocked(int worldIndex, int levelIndex, Set<String> completed) {
    if (!isWorldUnlocked(worldIndex, completed)) return false;
    if (levelIndex == 0) return true;
    final world = WorldCatalog.worlds[worldIndex];
    return completed.contains(levelKey(world.id, levelIndex - 1));
  }
}

/// Habilidades y estadísticas por personaje (distintas entre sí).
class CharacterLoadout {
  const CharacterLoadout({
    required this.primary,
    required this.secondary,
    required this.speed,
    required this.defense,
    required this.maxHp,
  });

  final AbilityKind primary;
  final AbilityKind secondary;

  /// 1..5, para mostrar en el selector y escalar el movimiento.
  final int speed;
  final int defense;
  final int maxHp;

  List<AbilityKind> get abilities => [primary, secondary];

  static CharacterLoadout of(PlayerCharacter character) => _table[character]!;

  static const Map<PlayerCharacter, CharacterLoadout> _table = {
    PlayerCharacter.chomper: CharacterLoadout(
      primary: AbilityKind.speed,
      secondary: AbilityKind.fireball,
      speed: 5,
      defense: 2,
      maxHp: 3,
    ),
    PlayerCharacter.penguin: CharacterLoadout(
      primary: AbilityKind.freeze,
      secondary: AbilityKind.shield,
      speed: 2,
      defense: 5,
      maxHp: 5,
    ),
    PlayerCharacter.ball: CharacterLoadout(
      primary: AbilityKind.teleport,
      secondary: AbilityKind.speed,
      speed: 4,
      defense: 3,
      maxHp: 4,
    ),
    PlayerCharacter.ghost: CharacterLoadout(
      primary: AbilityKind.sword,
      secondary: AbilityKind.invisibility,
      speed: 3,
      defense: 1,
      maxHp: 3,
    ),
  };
}
