import 'package:flutter/material.dart';

import '../models/maze_level.dart';
import '../models/player_progress.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/world_theme.dart';
import '../widgets/animated_action_button.dart';

class LevelsScreen extends StatelessWidget {
  const LevelsScreen({required this.onSelect, super.key});

  final ValueChanged<MazeLevel> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Scaffold(
      appBar: AppBar(title: const Text('Niveles')),
      body: FutureBuilder<PlayerProgress>(
        future: StorageService.loadProgress(),
        builder: (context, snapshot) {
          final progress = snapshot.data ?? const PlayerProgress.empty();
          return LayoutBuilder(
            builder: (context, constraints) {
              final viewportWidth = constraints.maxWidth
                  .clamp(0, 1000)
                  .toDouble();
              final padding = viewportWidth < 380 ? 14.0 : 22.0;
              final width = (viewportWidth - padding * 2)
                  .clamp(0, 1000)
                  .toDouble();
              final columns = width >= 760 ? 2 : 1;
              final cardWidth = columns == 1 ? width : (width - 12) / columns;
              return SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: ListView(
                      padding: EdgeInsets.all(padding),
                      children: [
                        Text(
                          'Elige tu mundo',
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Completa cada aventura para descubrir el siguiente mundo.',
                          style: TextStyle(color: colors.muted),
                        ),
                        const SizedBox(height: 14),
                        _ProgressBanner(progress: progress),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (
                              var index = 0;
                              index < MazeLevel.values.length;
                              index++
                            )
                              SizedBox(
                                width: cardWidth,
                                child: _LevelCard(
                                  level: MazeLevel.values[index],
                                  number: index + 1,
                                  progress: progress,
                                  onSelect: () =>
                                      onSelect(MazeLevel.values[index]),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        AnimatedActionButton(
                          label: 'VOLVER AL MENÚ',
                          icon: Icons.home_rounded,
                          primary: false,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.number,
    required this.progress,
    required this.onSelect,
  });

  final MazeLevel level;
  final int number;
  final PlayerProgress progress;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    final world = WorldTheme.forLevel(
      level,
      darkMode: Theme.of(context).brightness == Brightness.dark,
    );
    final unlocked = progress.isUnlocked(number - 1);
    final completed = progress.completedLevels.contains(number - 1);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.muted.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: world.accent.withValues(alpha: unlocked ? 0.10 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [world.wall, world.accent],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(level.icon, style: const TextStyle(fontSize: 30)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${number.toString().padLeft(2, '0')} · ${level.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${level.dimensions} · ${_difficultyLabel(level)}',
                      style: TextStyle(color: colors.muted),
                    ),
                  ],
                ),
              ),
              if (!unlocked)
                Icon(Icons.lock_rounded, color: colors.muted)
              else if (completed)
                Icon(Icons.check_circle_rounded, color: world.accent)
              else
                Icon(Icons.lock_open_rounded, color: world.accent),
            ],
          ),
          const SizedBox(height: 10),
          Text(level.description, style: TextStyle(color: colors.muted)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var star = 0; star < 3; star++)
                Icon(
                  star < progress.starsForLevel(number - 1)
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 20,
                  color: world.secondary,
                ),
              const Spacer(),
              if (completed)
                Text(
                  'Mejor: ${progress.bestScoreForLevel(number - 1)} pts',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedActionButton(
            label: unlocked
                ? completed
                      ? 'JUGAR DE NUEVO'
                      : 'EXPLORAR MUNDO'
                : 'COMPLETA EL NIVEL ANTERIOR',
            icon: Icons.play_arrow_rounded,
            onPressed: unlocked ? onSelect : null,
            primary: unlocked,
          ),
        ],
      ),
    );
  }

  String _difficultyLabel(MazeLevel level) => switch (level.difficulty) {
    MazeDifficulty.easy || MazeDifficulty.medium => 'Aventura',
    MazeDifficulty.hard => 'Desafío',
    MazeDifficulty.expert => 'Experto',
    MazeDifficulty.extreme => 'Épico',
  };
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.progress});

  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(Icons.stars_rounded, color: colors.mint, size: 26),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '${progress.totalStars} estrellas · ${progress.completedLevels.length}/5 mundos',
              style: TextStyle(
                color: colors.background,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 76,
            child: LinearProgressIndicator(
              value:
                  (progress.highestUnlockedLevel + 1) / MazeLevel.values.length,
              minHeight: 6,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: colors.background.withValues(alpha: 0.18),
              color: colors.mint,
            ),
          ),
        ],
      ),
    );
  }
}
