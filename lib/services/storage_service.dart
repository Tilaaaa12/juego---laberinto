import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/audio_preferences.dart';
import '../models/player_progress.dart';
import '../models/player_character.dart';

class StorageService {
  static const _darkModeKey = 'maze.dark_mode';
  static const _characterKey = 'maze.selected_character';
  static const _musicEnabledKey = 'maze.music_enabled';
  static const _effectsEnabledKey = 'maze.effects_enabled';
  static const _musicVolumeKey = 'maze.music_volume';
  static const _effectsVolumeKey = 'maze.effects_volume';
  static const _progressKey = 'maze.player_progress';

  static String _bestTimeKey(String level) => 'maze.best_time.$level';

  static Future<bool> loadDarkMode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_darkModeKey) ?? false;
  }

  static Future<void> saveDarkMode(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_darkModeKey, enabled);
  }

  static Future<PlayerCharacter> loadCharacter() async {
    final preferences = await SharedPreferences.getInstance();
    return PlayerCharacter.fromStorage(preferences.getString(_characterKey));
  }

  static Future<void> saveCharacter(PlayerCharacter character) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_characterKey, character.storageKey);
  }

  static Future<AudioPreferences> loadAudioPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    return AudioPreferences(
      musicEnabled:
          preferences.getBool(_musicEnabledKey) ??
          AudioPreferences.defaults.musicEnabled,
      effectsEnabled:
          preferences.getBool(_effectsEnabledKey) ??
          AudioPreferences.defaults.effectsEnabled,
      musicVolume:
          preferences.getDouble(_musicVolumeKey) ??
          AudioPreferences.defaults.musicVolume,
      effectsVolume:
          preferences.getDouble(_effectsVolumeKey) ??
          AudioPreferences.defaults.effectsVolume,
    );
  }

  static Future<void> saveAudioPreferences(AudioPreferences settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_musicEnabledKey, settings.musicEnabled);
    await preferences.setBool(_effectsEnabledKey, settings.effectsEnabled);
    await preferences.setDouble(_musicVolumeKey, settings.musicVolume);
    await preferences.setDouble(_effectsVolumeKey, settings.effectsVolume);
  }

  static Future<int?> loadBestTime(String level) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_bestTimeKey(level));
  }

  static Future<bool> saveBestTime(String level, int seconds) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _bestTimeKey(level);
    final bestTime = preferences.getInt(key);
    if (bestTime != null && bestTime <= seconds) return false;
    await preferences.setInt(key, seconds);
    return true;
  }

  static Future<PlayerProgress> loadProgress() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_progressKey);
    if (encoded == null) return const PlayerProgress.empty();
    final data = jsonDecode(encoded) as Map<String, dynamic>;
    final rawStars = data['stars'] as Map<String, dynamic>? ?? {};
    final rawScores = data['scores'] as Map<String, dynamic>? ?? {};
    return PlayerProgress(
      highestUnlockedLevel:
          (data['unlocked'] as num?)?.toInt().clamp(0, 4).toInt() ?? 0,
      totalStars: (data['totalStars'] as num?)?.toInt() ?? 0,
      completedLevels: ((data['completed'] as List<dynamic>?) ?? const [])
          .map((value) => (value as num).toInt())
          .toSet(),
      starsByLevel: rawStars.map(
        (key, value) => MapEntry(int.parse(key), (value as num).toInt()),
      ),
      bestScores: rawScores.map(
        (key, value) => MapEntry(int.parse(key), (value as num).toInt()),
      ),
    );
  }

  static Future<PlayerProgress> recordLevelCompletion({
    required int levelIndex,
    required int stars,
    required int score,
  }) async {
    if (levelIndex < 0 || levelIndex >= 5 || stars < 0 || stars > 3) {
      throw ArgumentError('Datos de progreso fuera de rango.');
    }
    final previous = await loadProgress();
    final previousStars = previous.starsForLevel(levelIndex);
    final starsByLevel = Map<int, int>.of(previous.starsByLevel);
    starsByLevel[levelIndex] = stars > previousStars ? stars : previousStars;
    final scores = Map<int, int>.of(previous.bestScores);
    if (score > (scores[levelIndex] ?? 0)) scores[levelIndex] = score;
    final completed = Set<int>.of(previous.completedLevels)..add(levelIndex);
    final progress = PlayerProgress(
      highestUnlockedLevel: max(
        previous.highestUnlockedLevel,
        min(levelIndex + 1, 4),
      ),
      totalStars:
          previous.totalStars + (starsByLevel[levelIndex]! - previousStars),
      completedLevels: completed,
      starsByLevel: starsByLevel,
      bestScores: scores,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _progressKey,
      jsonEncode({
        'unlocked': progress.highestUnlockedLevel,
        'totalStars': progress.totalStars,
        'completed': progress.completedLevels.toList(),
        'stars': {
          for (final entry in progress.starsByLevel.entries)
            entry.key.toString(): entry.value,
        },
        'scores': {
          for (final entry in progress.bestScores.entries)
            entry.key.toString(): entry.value,
        },
      }),
    );
    return progress;
  }
}
