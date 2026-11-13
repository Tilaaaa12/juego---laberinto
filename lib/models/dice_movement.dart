import 'dart:math';

class DiceMovement {
  int? result;
  int remaining = 0;
  int used = 0;

  bool get canRoll => remaining == 0;

  int? roll({Random? random}) {
    if (!canRoll) return null;
    result = (random ?? Random()).nextInt(6) + 1;
    remaining = result!;
    return result;
  }

  bool consume() {
    if (remaining == 0) return false;
    remaining--;
    used++;
    return true;
  }

  void reset() {
    result = null;
    remaining = 0;
    used = 0;
  }
}
