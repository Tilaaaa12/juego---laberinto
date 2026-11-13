import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/audio_preferences.dart';
import '../models/maze_level.dart';
import 'storage_service.dart';

enum GameSound {
  diceRoll('audio/dice_roll.wav'),
  diceResult('audio/dice_result.wav'),
  move('audio/move.wav'),
  collect('audio/collect.wav'),
  wall('audio/wall.wav'),
  damage('audio/damage.wav'),
  victory('audio/victory.wav'),
  select('audio/select.wav');

  const GameSound(this.asset);

  final String asset;
}

class GameAudioService {
  static final _musicPlayer = AudioPlayer();
  static final _effectsPlayer = AudioPlayer();
  static AudioPreferences _preferences = AudioPreferences.defaults;
  static MazeLevel? _activeLevel;
  static MazeLevel? _playingLevel;
  static Future<AudioPreferences>? _preferencesFuture;
  static bool _hasPreferenceOverride = false;

  static Future<AudioPreferences> loadPreferences() {
    return _preferencesFuture ??= StorageService.loadAudioPreferences().then((
      preferences,
    ) {
      if (!_hasPreferenceOverride) _preferences = preferences;
      return _preferences;
    });
  }

  static Future<void> startLevel(MazeLevel level) async {
    _activeLevel = level;
    if (_preferencesFuture == null) await loadPreferences();
    final preferences = _preferences;
    if (!preferences.musicEnabled) {
      if (_playingLevel != null) await stopMusic();
      _activeLevel = level;
      return;
    }
    await _playLevelMusic(level, preferences.musicVolume);
  }

  static Future<void> updatePreferences(
    AudioPreferences preferences, {
    MazeLevel? currentLevel,
  }) async {
    final previous = _preferences;
    _preferences = preferences;
    _hasPreferenceOverride = true;
    _activeLevel = currentLevel ?? _activeLevel;
    if (!preferences.musicEnabled) {
      if (_playingLevel != null) {
        await _reportAudioError(_musicPlayer.stop);
      }
      _playingLevel = null;
      return;
    }
    final level = _activeLevel;
    if (level == null) return;

    if (!previous.musicEnabled || _playingLevel != level) {
      await _playLevelMusic(level, preferences.musicVolume);
    } else {
      await _reportAudioError(
        () => _musicPlayer.setVolume(preferences.musicVolume),
      );
    }
  }

  static Future<void> playEffect(GameSound sound) async {
    if (_preferencesFuture == null) await loadPreferences();
    final preferences = _preferences;
    if (!preferences.effectsEnabled || preferences.effectsVolume == 0) return;
    await _reportAudioError(() async {
      await _effectsPlayer.setVolume(preferences.effectsVolume);
      await _effectsPlayer.play(AssetSource(sound.asset));
    });
  }

  static Future<void> pauseMusic() async {
    if (_playingLevel == null) return;
    await _reportAudioError(_musicPlayer.pause);
  }

  static Future<void> resumeMusic() async {
    if (!_preferences.musicEnabled ||
        _activeLevel == null ||
        _playingLevel == null) {
      return;
    }
    await _reportAudioError(_musicPlayer.resume);
  }

  static Future<void> stopMusic() async {
    if (_playingLevel != null) await _reportAudioError(_musicPlayer.stop);
    _activeLevel = null;
    _playingLevel = null;
  }

  static Future<void> _playLevelMusic(MazeLevel level, double volume) async {
    if (_playingLevel == level && _musicPlayer.state == PlayerState.playing) {
      await _reportAudioError(() => _musicPlayer.setVolume(volume));
      return;
    }
    await _reportAudioError(() async {
      await _musicPlayer.stop();
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(volume);
      await _musicPlayer.play(AssetSource(_musicAsset(level)));
      _playingLevel = level;
    });
  }

  static String _musicAsset(MazeLevel level) {
    return switch (level.difficulty) {
      MazeDifficulty.easy => 'audio/level_easy.wav',
      MazeDifficulty.medium => 'audio/level_medium.wav',
      MazeDifficulty.hard => 'audio/level_jungle.wav',
      MazeDifficulty.expert => 'audio/level_lab.wav',
      MazeDifficulty.extreme => 'audio/level_lava.wav',
    };
  }

  static Future<void> _reportAudioError(
    Future<void> Function() operation,
  ) async {
    try {
      await operation();
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Maze Adventure audio',
        ),
      );
    }
  }
}
