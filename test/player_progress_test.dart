import 'package:flutter_test/flutter_test.dart';
import 'package:juego_laberinto/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'completion unlocks the next themed level and keeps best rewards',
    () async {
      SharedPreferences.setMockInitialValues({});

      final first = await StorageService.recordLevelCompletion(
        levelIndex: 0,
        stars: 2,
        score: 1200,
      );
      expect(first.highestUnlockedLevel, 1);
      expect(first.totalStars, 2);

      final improved = await StorageService.recordLevelCompletion(
        levelIndex: 0,
        stars: 3,
        score: 900,
      );
      expect(improved.totalStars, 3);
      expect(improved.bestScoreForLevel(0), 1200);
      expect(improved.completedLevels, contains(0));

      final next = await StorageService.recordLevelCompletion(
        levelIndex: 1,
        stars: 1,
        score: 800,
      );
      expect(next.highestUnlockedLevel, 2);
      expect((await StorageService.loadProgress()).completedLevels, {0, 1});
    },
  );
}
