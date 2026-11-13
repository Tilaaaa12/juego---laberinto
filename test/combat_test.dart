import 'package:flutter_test/flutter_test.dart';
import 'package:juego_laberinto/models/combat.dart';

void main() {
  test('obstacles only accept their intended weapon types', () {
    expect(
      ObstacleType.woodenCrate.canBeDamagedBy(WeaponType.fireball),
      isTrue,
    );
    expect(ObstacleType.woodenCrate.canBeDamagedBy(WeaponType.sword), isTrue);
    expect(
      ObstacleType.woodenCrate.canBeDamagedBy(WeaponType.lightning),
      isFalse,
    );
    expect(
      ObstacleType.magicBarrier.canBeDamagedBy(WeaponType.lightning),
      isTrue,
    );
    expect(
      ObstacleType.lockedDoor.canBeDamagedBy(WeaponType.lightning),
      isFalse,
    );
  });

  test('obstacle durability and weapon unlock milestones are explicit', () {
    expect(ObstacleType.woodenCrate.durability, 1);
    expect(ObstacleType.fragileRock.durability, 2);
    expect(WeaponType.fireball.unlockLevel, 1);
    expect(WeaponType.darts.unlockLevel, 2);
    expect(WeaponType.lightning.unlockLevel, 3);
  });
}
