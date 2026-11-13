import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all level music and game effects are bundled as WAV files', () async {
    const assets = [
      'level_easy.wav',
      'level_medium.wav',
      'level_hard.wav',
      'level_jungle.wav',
      'level_lab.wav',
      'level_lava.wav',
      'dice_roll.wav',
      'dice_result.wav',
      'move.wav',
      'collect.wav',
      'wall.wav',
      'damage.wav',
      'victory.wav',
      'select.wav',
    ];

    for (final asset in assets) {
      final data = await rootBundle.load('assets/audio/$asset');
      expect(data.lengthInBytes, greaterThan(44), reason: asset);
      expect(_readAscii(data, 0, 4), 'RIFF', reason: asset);
      expect(_readAscii(data, 8, 4), 'WAVE', reason: asset);
      expect(_readAscii(data, 36, 4), 'data', reason: asset);
    }
  });
}

String _readAscii(ByteData data, int offset, int length) {
  return String.fromCharCodes(
    List.generate(length, (index) => data.getUint8(offset + index)),
  );
}
