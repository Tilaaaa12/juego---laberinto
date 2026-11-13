import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:juego_laberinto/models/dice_movement.dart';

void main() {
  test('dice results stay between one and six', () {
    final dice = DiceMovement();
    final random = Random(23);

    for (var roll = 0; roll < 30; roll++) {
      final result = dice.roll(random: random);
      expect(result, inInclusiveRange(1, 6));
      while (dice.remaining > 0) {
        expect(dice.consume(), isTrue);
      }
    }
  });

  test('cannot reroll until valid steps consume the full result', () {
    final dice = DiceMovement();
    final firstRoll = dice.roll(random: Random(4))!;

    expect(dice.roll(random: Random(9)), isNull);
    expect(dice.consume(), isTrue);
    expect(dice.used, 1);
    if (firstRoll > 1) {
      expect(dice.roll(random: Random(9)), isNull);
    }
    while (dice.remaining > 0) {
      dice.consume();
    }
    expect(dice.roll(random: Random(9)), inInclusiveRange(1, 6));

    dice.reset();
    expect(dice.result, isNull);
    expect(dice.remaining, 0);
    expect(dice.used, 0);
  });
}
