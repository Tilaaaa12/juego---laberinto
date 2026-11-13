import 'dart:math';

import 'enemy.dart';
import 'pathfinding.dart';

enum AbilityKind {
  fireball,
  sword,
  shield,
  speed,
  invisibility,
  freeze,
  heal,
  teleport,
}

class AbilityDef {
  const AbilityDef({
    required this.kind,
    required this.label,
    required this.cooldownMs,
    this.durationMs = 0,
    this.range = 0,
    this.power = 0,
    this.maxUses,
  });

  final AbilityKind kind;
  final String label;
  final int cooldownMs;

  /// Duración del efecto (escudo, velocidad, invisibilidad, congelación).
  final int durationMs;

  /// Alcance en casillas (proyectil, espada, congelación, teletransporte).
  final int range;

  /// Daño o curación.
  final int power;

  /// Usos máximos por nivel; null = ilimitado.
  final int? maxUses;
}

const Map<AbilityKind, AbilityDef> abilityCatalog = {
  AbilityKind.fireball: AbilityDef(
    kind: AbilityKind.fireball,
    label: 'Bola de fuego',
    cooldownMs: 2500,
    range: 6,
    power: 2,
  ),
  AbilityKind.sword: AbilityDef(
    kind: AbilityKind.sword,
    label: 'Espada',
    cooldownMs: 900,
    range: 1,
    power: 3,
  ),
  AbilityKind.shield: AbilityDef(
    kind: AbilityKind.shield,
    label: 'Escudo mágico',
    cooldownMs: 9000,
    durationMs: 3000,
  ),
  AbilityKind.speed: AbilityDef(
    kind: AbilityKind.speed,
    label: 'Velocidad especial',
    cooldownMs: 8000,
    durationMs: 2500,
  ),
  AbilityKind.invisibility: AbilityDef(
    kind: AbilityKind.invisibility,
    label: 'Invisibilidad',
    cooldownMs: 12000,
    durationMs: 3500,
  ),
  AbilityKind.freeze: AbilityDef(
    kind: AbilityKind.freeze,
    label: 'Congelación',
    cooldownMs: 10000,
    durationMs: 3000,
    range: 4,
  ),
  AbilityKind.heal: AbilityDef(
    kind: AbilityKind.heal,
    label: 'Curación',
    cooldownMs: 15000,
    power: 1,
    maxUses: 2,
  ),
  AbilityKind.teleport: AbilityDef(
    kind: AbilityKind.teleport,
    label: 'Teletransporte corto',
    cooldownMs: 7000,
    range: 3,
    maxUses: 4,
  ),
};

/// Controla cooldowns, duraciones y usos. Recibe el reloj de juego en ms,
/// de modo que al pausar basta con no avanzar el reloj (o llamar a [shift]).
class AbilityController {
  AbilityController(this.loadout, {this.catalog = abilityCatalog}) {
    for (final kind in loadout) {
      _uses[kind] = 0;
    }
  }

  final List<AbilityKind> loadout;
  final Map<AbilityKind, AbilityDef> catalog;
  final Map<AbilityKind, int> _readyAt = {};
  final Map<AbilityKind, int> _activeUntil = {};
  final Map<AbilityKind, int> _uses = {};

  AbilityDef def(AbilityKind kind) => catalog[kind]!;

  bool canUse(AbilityKind kind, int nowMs) {
    if (!loadout.contains(kind)) return false;
    if (nowMs < (_readyAt[kind] ?? 0)) return false;
    final limit = def(kind).maxUses;
    return limit == null || (_uses[kind] ?? 0) < limit;
  }

  /// Gasta la habilidad. Devuelve false si no se pudo usar.
  bool activate(AbilityKind kind, int nowMs) {
    if (!canUse(kind, nowMs)) return false;
    final d = def(kind);
    _readyAt[kind] = nowMs + d.cooldownMs;
    if (d.durationMs > 0) _activeUntil[kind] = nowMs + d.durationMs;
    _uses[kind] = (_uses[kind] ?? 0) + 1;
    return true;
  }

  bool isActive(AbilityKind kind, int nowMs) =>
      nowMs < (_activeUntil[kind] ?? 0);

  int cooldownRemaining(AbilityKind kind, int nowMs) =>
      max(0, (_readyAt[kind] ?? 0) - nowMs);

  /// 0 = lista, 1 = recién usada.
  double cooldownFraction(AbilityKind kind, int nowMs) {
    final total = def(kind).cooldownMs;
    return total == 0 ? 0 : cooldownRemaining(kind, nowMs) / total;
  }

  int? usesLeft(AbilityKind kind) {
    final limit = def(kind).maxUses;
    return limit == null ? null : limit - (_uses[kind] ?? 0);
  }

  /// Desplaza todos los temporizadores [pausedMs] (para reanudar tras una pausa).
  void shift(int pausedMs) {
    for (final map in [_readyAt, _activeUntil]) {
      for (final key in map.keys.toList()) {
        map[key] = map[key]! + pausedMs;
      }
    }
  }

  void reset() {
    _readyAt.clear();
    _activeUntil.clear();
    for (final kind in loadout) {
      _uses[kind] = 0;
    }
  }
}

/// Efectos de las habilidades sobre el mundo. Todo respeta los muros.
class AbilityEffects {
  /// Proyectil recto: avanza hasta [range] casillas, se detiene en muros
  /// (celdas no transitables) y daña al primer enemigo vivo que alcance.
  static Enemy? fireProjectile({
    required Cell origin,
    required Cell direction,
    required List<Enemy> enemies,
    required bool Function(Cell) passable,
    required int range,
    required int damage,
  }) {
    var cell = origin;
    for (var i = 0; i < range; i++) {
      cell = Cell(cell.x + direction.x, cell.y + direction.y);
      if (!passable(cell)) return null;
      for (final enemy in enemies) {
        if (enemy.isAlive && enemy.position == cell) {
          enemy.takeDamage(damage);
          enemy.knockBack(origin, 1, passable);
          return enemy;
        }
      }
    }
    return null;
  }

  /// Espada: golpea a todos los enemigos a [range] pasos de pasillo
  /// (no atraviesa muros).
  static List<Enemy> swordSwing({
    required Cell origin,
    required List<Enemy> enemies,
    required bool Function(Cell) passable,
    required int range,
    required int damage,
  }) {
    final reach = bfsDistances(origin, passable, maxDistance: range);
    final hit = <Enemy>[];
    for (final enemy in enemies) {
      if (enemy.isAlive && reach.containsKey(enemy.position)) {
        enemy.takeDamage(damage);
        enemy.knockBack(origin, 1, passable);
        hit.add(enemy);
      }
    }
    return hit;
  }

  /// Congela a los enemigos dentro de [range] pasos de pasillo.
  static List<Enemy> freezeNearby({
    required Cell origin,
    required List<Enemy> enemies,
    required bool Function(Cell) passable,
    required int range,
    required int ticks,
  }) {
    final reach = bfsDistances(origin, passable, maxDistance: range);
    final frozen = <Enemy>[];
    for (final enemy in enemies) {
      if (enemy.isAlive && reach.containsKey(enemy.position)) {
        enemy.freeze(ticks);
        frozen.add(enemy);
      }
    }
    return frozen;
  }

  /// Teletransporte en línea recta: llega hasta [range] casillas pero se
  /// detiene ante el primer muro (no atraviesa paredes).
  static Cell teleportTarget({
    required Cell origin,
    required Cell direction,
    required bool Function(Cell) passable,
    required int range,
  }) {
    var cell = origin;
    for (var i = 0; i < range; i++) {
      final next = Cell(cell.x + direction.x, cell.y + direction.y);
      if (!passable(next)) break;
      cell = next;
    }
    return cell;
  }

  static int heal(int hp, int maxHp, int amount) =>
      min(maxHp, max(0, hp + amount));
}
