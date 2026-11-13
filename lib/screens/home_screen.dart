import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/audio_preferences.dart';
import '../models/maze_level.dart';
import '../models/player_progress.dart';
import '../models/player_character.dart';
import '../services/game_audio_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/world_theme.dart';
import '../widgets/animated_action_button.dart';
import '../widgets/character_avatar.dart';
import '../widgets/sparkle_field.dart';
import 'levels_screen.dart';
import 'settings_screen.dart';
import 'instructions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.onStart,
    required this.isDarkMode,
    required this.onThemeChanged,
    super.key,
  });

  final void Function(String, MazeLevel, PlayerCharacter) onStart;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();
  MazeLevel _selectedLevel = MazeLevel.values.first;
  PlayerCharacter _selectedCharacter = PlayerCharacter.chomper;
  final _characterSectionKey = GlobalKey();
  PlayerProgress _progress = const PlayerProgress.empty();
  AudioPreferences _audioPreferences = AudioPreferences.defaults;
  late final Future<void> _characterLoad;
  bool _characterLoaded = false;
  bool _characterChanged = false;

  @override
  void initState() {
    super.initState();
    _characterLoad = _loadCharacter();
    unawaited(_loadProgress());
    unawaited(_loadAudioPreferences());
  }

  Future<void> _loadProgress() async {
    try {
      final progress = await StorageService.loadProgress();
      if (mounted) {
        setState(() {
          _progress = progress;
          if (!progress.isUnlocked(_selectedLevel.index)) {
            _selectedLevel = MazeLevel.values[progress.highestUnlockedLevel];
          }
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar el progreso: $error')),
        );
      }
    }
  }

  Future<void> _loadAudioPreferences() async {
    try {
      final preferences = await StorageService.loadAudioPreferences();
      if (mounted) setState(() => _audioPreferences = preferences);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar el audio: $error')),
        );
      }
    }
  }

  Future<void> _loadCharacter() async {
    try {
      final character = await StorageService.loadCharacter();
      if (mounted) {
        setState(() {
          if (!_characterChanged) _selectedCharacter = character;
          _characterLoaded = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _characterLoaded = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar el personaje: $error')),
        );
      }
    }
  }

  String get _playerName {
    final name = _nameController.text.trim();
    return name.isEmpty ? 'Estudiante' : name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _openLevels() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LevelsScreen(
          onSelect: (level) {
            Navigator.of(context).pop();
            unawaited(_startGame(level));
          },
        ),
      ),
    );
  }

  Future<void> _selectCharacter(PlayerCharacter character) async {
    _characterChanged = true;
    setState(() => _selectedCharacter = character);
    try {
      await StorageService.saveCharacter(character);
      unawaited(GameAudioService.playEffect(GameSound.select));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el personaje: $error')),
        );
      }
    }
  }

  Future<void> _startGame(MazeLevel level) async {
    if (!_characterLoaded) await _characterLoad;
    late final PlayerProgress progress;
    try {
      progress = await StorageService.loadProgress();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo consultar el progreso: $error')),
        );
      }
      return;
    }
    if (!mounted) return;
    if (!progress.isUnlocked(level.index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa el mundo anterior para desbloquearlo.'),
        ),
      );
      return;
    }
    widget.onStart(_playerName, level, _selectedCharacter);
  }

  Future<void> _toggleMusic() async {
    final updated = _audioPreferences.copyWith(
      musicEnabled: !_audioPreferences.musicEnabled,
    );
    setState(() => _audioPreferences = updated);
    try {
      await StorageService.saveAudioPreferences(updated);
      await GameAudioService.updatePreferences(updated);
      await GameAudioService.playEffect(GameSound.select);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el audio: $error')),
        );
      }
    }
  }

  Future<void> _toggleEffects() async {
    final updated = _audioPreferences.copyWith(
      effectsEnabled: !_audioPreferences.effectsEnabled,
    );
    setState(() => _audioPreferences = updated);
    try {
      await StorageService.saveAudioPreferences(updated);
      await GameAudioService.updatePreferences(updated);
      if (updated.effectsEnabled) {
        await GameAudioService.playEffect(GameSound.select);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el audio: $error')),
        );
      }
    }
  }

  void _showInstructions() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const InstructionsScreen()));
  }

  void _showCharacters() {
    final target = _characterSectionKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          isDarkMode: widget.isDarkMode,
          onThemeChanged: widget.onThemeChanged,
          onAudioChanged: GameAudioService.updatePreferences,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    final world = WorldTheme.forLevel(
      _selectedLevel,
      darkMode: Theme.of(context).brightness == Brightness.dark,
    );
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(child: SparkleField(color: world.secondary)),
            ),
            LayoutBuilder(
              builder: (context, viewport) {
                final horizontalPadding = viewport.maxWidth < 380 ? 14.0 : 26.0;
                final contentWidth = viewport.maxWidth - horizontalPadding * 2;
                final desktopLayout =
                    contentWidth >= 860 && viewport.maxHeight >= 520;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: viewport.maxHeight < 600 ? 12 : 22,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          viewport.maxHeight -
                          (viewport.maxHeight < 600 ? 24 : 44),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1220),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(colors, contentWidth),
                            const SizedBox(height: 20),
                            if (desktopLayout)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        _buildHero(
                                          colors,
                                          world,
                                          contentWidth * 0.44,
                                        ),
                                        const SizedBox(height: 14),
                                        _ProgressCard(progress: _progress),
                                        const SizedBox(height: 14),
                                        _buildQuickActions(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 22),
                                  Expanded(
                                    flex: 6,
                                    child: _buildPlayerPanel(
                                      colors,
                                      contentWidth * 0.52,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildHero(colors, world, contentWidth),
                                  const SizedBox(height: 12),
                                  _ProgressCard(progress: _progress),
                                  const SizedBox(height: 14),
                                  _buildPlayerPanel(colors, contentWidth),
                                  const SizedBox(height: 14),
                                  _buildQuickActions(),
                                ],
                              ),
                          ],
                        ),
                      ),
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

  Widget _buildHeader(GameColors colors, double availableWidth) {
    final brand = SizedBox(
      width: min(260, availableWidth * 0.48),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.forest, colors.ink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: colors.forest.withValues(alpha: 0.24),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.route_rounded, color: colors.mint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'MAZE ADVENTURE',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.ink,
                fontSize: availableWidth < 360 ? 12 : 14,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    final credit = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        'ELABORADO POR: ING. BALLADARES',
        textAlign: TextAlign.right,
        style: TextStyle(
          color: colors.mint,
          fontSize: availableWidth < 360 ? 9 : 10,
          letterSpacing: 0.35,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final controls = Wrap(
      spacing: 2,
      children: [
        _HeaderIconButton(
          tooltip: widget.isDarkMode
              ? 'Activar modo claro'
              : 'Activar modo oscuro',
          icon: widget.isDarkMode
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
        ),
        _HeaderIconButton(
          tooltip: _audioPreferences.musicEnabled
              ? 'Silenciar música'
              : 'Activar música',
          icon: _audioPreferences.musicEnabled
              ? Icons.music_note_rounded
              : Icons.music_off_rounded,
          onPressed: _toggleMusic,
        ),
        _HeaderIconButton(
          tooltip: _audioPreferences.effectsEnabled
              ? 'Silenciar efectos'
              : 'Activar efectos',
          icon: _audioPreferences.effectsEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          onPressed: _toggleEffects,
        ),
        _HeaderIconButton(
          tooltip: 'Configuración',
          icon: Icons.tune_rounded,
          onPressed: _openSettings,
        ),
      ],
    );
    if (availableWidth >= 720) {
      return Column(
        children: [
          Row(children: [brand, const Spacer(), credit]),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [controls]),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        brand,
        Align(alignment: Alignment.centerRight, child: credit),
        Align(alignment: Alignment.centerRight, child: controls),
      ],
    );
  }

  Widget _buildHero(GameColors colors, WorldTheme world, double width) {
    final compact = width < 500;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [world.wall, colors.ink, world.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: world.accent.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(child: SparkleField(color: world.secondary)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.mint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'AVENTURA · NIVEL ${_selectedLevel.index + 1}',
                      style: TextStyle(
                        color: colors.wall,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.flag_rounded, color: colors.coral, size: 28),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final avatarSize = min(
                    width < 380
                        ? 68.0
                        : compact
                        ? 88.0
                        : 118.0,
                    constraints.maxWidth * 0.28,
                  );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MAZE\nADVENTURE',
                              style: TextStyle(
                                color: colors.background,
                                fontSize: compact
                                    ? constraints.maxWidth < 300
                                          ? 27
                                          : constraints.maxWidth < 340
                                          ? 29
                                          : 31
                                    : 48,
                                height: 0.98,
                                fontWeight: FontWeight.w900,
                                letterSpacing: compact ? -0.5 : 0,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              _selectedLevel.title.toUpperCase(),
                              style: TextStyle(
                                color: world.secondary,
                                fontSize: 10,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: compact ? 6 : 14),
                      Container(
                        width: avatarSize + (compact ? 8 : 20),
                        height: avatarSize + (compact ? 8 : 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.background.withValues(alpha: 0.12),
                          border: Border.all(
                            color: world.secondary.withValues(alpha: 0.7),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: world.secondary.withValues(alpha: 0.22),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Center(
                          child: CharacterAvatar(
                            character: _selectedCharacter,
                            size: avatarSize,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Piensa el camino. Reúne estrellas. Encuentra la meta.',
                style: TextStyle(
                  color: colors.background.withValues(alpha: 0.86),
                  fontSize: compact ? 13 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: const [
                  _WorldBadge(icon: '🌲', label: 'Bosque'),
                  _WorldBadge(icon: '🏚️', label: 'Mansión'),
                  _WorldBadge(icon: '🗿', label: 'Templo'),
                  _WorldBadge(icon: '🤖', label: 'Laboratorio'),
                  _WorldBadge(icon: '🌋', label: 'Lava'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerPanel(GameColors colors, double width) {
    final characterColumns = width >= 600 ? 4 : 2;
    final levelColumns = width >= 560 ? 3 : 2;
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(width < 380 ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PREPARA TU AVENTURA',
              style: TextStyle(
                color: colors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              maxLength: 32,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Nombre del jugador',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              key: _characterSectionKey,
              child: Text(
                'SELECCIONA TU PERSONAJE',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: characterColumns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: characterColumns == 4 ? 0.93 : 1.2,
              children: [
                for (final character in PlayerCharacter.values)
                  _CharacterChoice(
                    character: character,
                    selected: _selectedCharacter == character,
                    onTap: () => _selectCharacter(character),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'NIVEL SELECCIONADO',
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openLevels,
                  child: const Text('Ver todos'),
                ),
              ],
            ),
            GridView.count(
              crossAxisCount: levelColumns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: levelColumns == 3 ? 1.42 : 2,
              children: [
                for (final level in MazeLevel.values)
                  _LevelChoice(
                    level: level,
                    selected: _selectedLevel == level,
                    unlocked: _progress.isUnlocked(level.index),
                    stars: _progress.starsForLevel(level.index),
                    onTap: () {
                      if (_progress.isUnlocked(level.index)) {
                        setState(() => _selectedLevel = level);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedActionButton(
              label: 'JUGAR',
              icon: Icons.play_arrow_rounded,
              onPressed: () => unawaited(_startGame(_selectedLevel)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [
      _MenuAction(
        label: 'SELECCIONAR NIVEL',
        icon: Icons.public_rounded,
        onPressed: _openLevels,
      ),
      _MenuAction(
        label: 'PERSONAJES',
        icon: Icons.face_retouching_natural,
        onPressed: _showCharacters,
      ),
      _MenuAction(
        label: 'INSTRUCCIONES DE JUEGO',
        icon: Icons.menu_book_rounded,
        onPressed: _showInstructions,
      ),
      _MenuAction(
        label: 'CONFIGURACIÓN',
        icon: Icons.tune_rounded,
        onPressed: _openSettings,
      ),
    ],
  );
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
    visualDensity: VisualDensity.compact,
    style: IconButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      minimumSize: const Size(40, 40),
    ),
  );
}

class _WorldBadge extends StatelessWidget {
  const _WorldBadge({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
    ),
    child: Text(
      '$icon $label',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 46),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class _CharacterChoice extends StatelessWidget {
  const _CharacterChoice({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  final PlayerCharacter character;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: character.displayName,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? colors.forest : colors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? colors.mint
                  : colors.muted.withValues(alpha: 0.22),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CharacterAvatar(
                character: character,
                size: 48,
                backgroundColor: selected ? colors.forest : colors.surface,
              ),
              Text(
                character.displayName,
                style: TextStyle(
                  color: selected ? Colors.white : colors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _characterTagline(character),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? colors.background : colors.muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _characterTagline(PlayerCharacter character) => switch (character) {
    PlayerCharacter.chomper => 'Valiente y veloz',
    PlayerCharacter.ghost => 'Amigo de los misterios',
    PlayerCharacter.ball => 'Rebota hacia la meta',
    PlayerCharacter.penguin => 'Explorador incansable',
  };
}

class _LevelChoice extends StatelessWidget {
  const _LevelChoice({
    required this.level,
    required this.selected,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final MazeLevel level;
  final bool selected;
  final bool unlocked;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Semantics(
      button: true,
      selected: selected,
      enabled: unlocked,
      child: InkWell(
        onTap: unlocked ? onTap : null,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
          decoration: BoxDecoration(
            color: selected ? colors.forest : colors.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? colors.forest
                  : colors.muted.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(level.icon, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      level.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : unlocked
                            ? colors.ink
                            : colors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!unlocked) ...[
                    const SizedBox(width: 3),
                    Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: selected ? colors.mint : colors.muted,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    level.dimensions,
                    style: TextStyle(
                      color: selected ? colors.mint : colors.muted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 4),
                  for (var i = 0; i < stars; i++)
                    Icon(Icons.star_rounded, size: 10, color: colors.mint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    final progressValue =
        (progress.completedLevels.length / MazeLevel.values.length).clamp(
          0.0,
          1.0,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.muted.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.mint.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.stars_rounded, color: colors.forest),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${progress.totalStars} estrellas · ${progress.completedLevels.length}/${MazeLevel.values.length} mundos',
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 6,
                    backgroundColor: colors.muted.withValues(alpha: 0.18),
                    color: colors.coral,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
