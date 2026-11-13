class AudioPreferences {
  const AudioPreferences({
    required this.musicEnabled,
    required this.effectsEnabled,
    required this.musicVolume,
    required this.effectsVolume,
  });

  static const defaults = AudioPreferences(
    musicEnabled: true,
    effectsEnabled: true,
    musicVolume: 0.55,
    effectsVolume: 0.75,
  );

  final bool musicEnabled;
  final bool effectsEnabled;
  final double musicVolume;
  final double effectsVolume;

  AudioPreferences copyWith({
    bool? musicEnabled,
    bool? effectsEnabled,
    double? musicVolume,
    double? effectsVolume,
  }) {
    return AudioPreferences(
      musicEnabled: musicEnabled ?? this.musicEnabled,
      effectsEnabled: effectsEnabled ?? this.effectsEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
      effectsVolume: effectsVolume ?? this.effectsVolume,
    );
  }
}
