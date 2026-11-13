import 'package:flutter/material.dart';

import '../models/audio_preferences.dart';
import '../models/maze_level.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.isDarkMode,
    required this.onThemeChanged,
    this.onAudioChanged,
    super.key,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final Future<void> Function(AudioPreferences)? onAudioChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDarkMode;
  AudioPreferences _audioPreferences = AudioPreferences.defaults;
  bool _audioChanged = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadAudioPreferences();
  }

  Future<void> _loadAudioPreferences() async {
    final preferences = await StorageService.loadAudioPreferences();
    if (mounted) {
      setState(() {
        if (!_audioChanged) _audioPreferences = preferences;
      });
    }
  }

  Future<void> _updateAudioPreferences(AudioPreferences preferences) async {
    setState(() {
      _audioChanged = true;
      _audioPreferences = preferences;
    });
    try {
      await StorageService.saveAudioPreferences(preferences);
      await widget.onAudioChanged?.call(preferences);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el audio: $error')),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _isDarkMode = widget.isDarkMode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Personaliza tu aventura',
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: SwitchListTile(
                    secondary: Icon(
                      _isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                    ),
                    title: const Text('Modo oscuro'),
                    subtitle: const Text(
                      'Guardar preferencia para la próxima vez',
                    ),
                    value: _isDarkMode,
                    onChanged: (value) {
                      setState(() => _isDarkMode = value);
                      widget.onThemeChanged(value);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _AudioSettingsCard(
                  preferences: _audioPreferences,
                  onChanged: _updateAudioPreferences,
                ),
                const SizedBox(height: 14),
                _InformationCard(
                  icon: Icons.menu_book_rounded,
                  title: 'Instrucciones',
                  children: const [
                    'Llega a la bandera sin atravesar las paredes.',
                    'Recoge las estrellas del camino para sumar puntos.',
                    'El cronómetro y los movimientos comienzan al abrir el nivel.',
                  ],
                ),
                const SizedBox(height: 12),
                _InformationCard(
                  icon: Icons.gamepad_rounded,
                  title: 'Controles',
                  children: const [
                    'Lanza el dado para recibir de 1 a 6 movimientos.',
                    'Usa las flechas o WASD para elegir dirección; Espacio lanza el dado.',
                    'Desliza sobre el tablero; Escape o el botón de pausa detiene la partida.',
                    'Paredes y obstáculos bloquean el paso sin gastar movimientos.',
                  ],
                ),
                const SizedBox(height: 12),
                _BestTimesCard(),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('VOLVER AL MENÚ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioSettingsCard extends StatelessWidget {
  const _AudioSettingsCard({
    required this.preferences,
    required this.onChanged,
  });

  final AudioPreferences preferences;
  final ValueChanged<AudioPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          children: [
            const ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(Icons.volume_up_rounded),
              title: Text(
                'Música y sonidos',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Música de nivel'),
              value: preferences.musicEnabled,
              onChanged: (enabled) =>
                  onChanged(preferences.copyWith(musicEnabled: enabled)),
            ),
            _VolumeControl(
              label: 'Volumen de música',
              value: preferences.musicVolume,
              enabled: preferences.musicEnabled,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(musicVolume: value)),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Efectos de sonido'),
              value: preferences.effectsEnabled,
              onChanged: (enabled) =>
                  onChanged(preferences.copyWith(effectsEnabled: enabled)),
            ),
            _VolumeControl(
              label: 'Volumen de efectos',
              value: preferences.effectsVolume,
              enabled: preferences.effectsEnabled,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(effectsVolume: value)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label · ${(value * 100).round()}%'),
          Slider(
            value: value.clamp(0.0, 1.0).toDouble(),
            min: 0,
            max: 1,
            divisions: 10,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<String> children;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.coral),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final line in children)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 7, color: colors.forest),
                    const SizedBox(width: 9),
                    Expanded(child: Text(line)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BestTimesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: colors.coral),
                const SizedBox(width: 9),
                const Text(
                  'Mejores tiempos',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final level in MazeLevel.values)
              FutureBuilder<int?>(
                future: StorageService.loadBestTime(level.title),
                builder: (context, snapshot) {
                  final seconds = snapshot.data;
                  final value = snapshot.connectionState != ConnectionState.done
                      ? 'Cargando…'
                      : seconds == null
                      ? 'Sin registro'
                      : _formatTime(seconds);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(level.title),
                    trailing: Text(
                      value,
                      style: TextStyle(
                        color: colors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
