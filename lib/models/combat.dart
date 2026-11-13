enum WeaponType {
  fireball('Bola de fuego', '🔥', 1),
  sword('Espada mágica', '⚔️', 1),
  darts('Dardos', '➶', 2),
  lightning('Rayo eléctrico', '⚡', 3);

  const WeaponType(this.label, this.symbol, this.unlockLevel);

  final String label;
  final String symbol;
  final int unlockLevel;
}

enum ObstacleType {
  woodenCrate('Caja', '▧', 1, {WeaponType.fireball, WeaponType.sword}),
  web('Telaraña', '✳', 1, {WeaponType.fireball, WeaponType.sword}),
  fragileRock('Roca frágil', '◆', 2, {WeaponType.lightning}),
  magicBarrier('Barrera mágica', '✦', 2, {WeaponType.lightning}),
  thornPlant('Planta espinosa', '♣', 1, {
    WeaponType.fireball,
    WeaponType.sword,
  }),
  crackedWall('Muro agrietado', '▤', 2, {
    WeaponType.fireball,
    WeaponType.lightning,
  }),
  magicCrystal('Cristal mágico', '♦', 2, {WeaponType.lightning}),
  lockedDoor('Puerta cerrada', '▣', 999, {});

  const ObstacleType(
    this.label,
    this.symbol,
    this.durability,
    this.vulnerabilities,
  );

  final String label;
  final String symbol;
  final int durability;
  final Set<WeaponType> vulnerabilities;

  bool canBeDamagedBy(WeaponType weapon) => vulnerabilities.contains(weapon);
}

class ActiveProjectile {
  const ActiveProjectile({
    required this.x,
    required this.y,
    required this.weapon,
  });

  final int x;
  final int y;
  final WeaponType weapon;
}
