import 'package:flutter_test/flutter_test.dart';
import 'package:juego_laberinto/models/audio_preferences.dart';
import 'package:juego_laberinto/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audio switches and volumes persist locally', () async {
    SharedPreferences.setMockInitialValues({});
    const settings = AudioPreferences(
      musicEnabled: false,
      effectsEnabled: true,
      musicVolume: 0.3,
      effectsVolume: 0.8,
    );

    await StorageService.saveAudioPreferences(settings);
    final loaded = await StorageService.loadAudioPreferences();

    expect(loaded.musicEnabled, isFalse);
    expect(loaded.effectsEnabled, isTrue);
    expect(loaded.musicVolume, 0.3);
    expect(loaded.effectsVolume, 0.8);
  });
}
