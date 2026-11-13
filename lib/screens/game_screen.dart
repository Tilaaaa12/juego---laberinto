import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyUpEvent, LogicalKeyboardKey;

import '../game/engine/enemy.dart' show EnemyAI;
import '../game/engine/pathfinding.dart' show bfsDistances;
import '../models/combat.dart';
import '../models/dice_movement.dart';
import '../models/maze_level.dart';
import '../models/player_character.dart';
import '../services/game_audio_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/world_theme.dart';
import '../widgets/character_avatar.dart';
import '../widgets/dice_face.dart';
import 'settings_screen.dart';

class MazeGameScreen extends StatefulWidget {
  const MazeGameScreen({
    required this.difficulty,
    required this.playerName,
    required this.character,
    required this.onThemeChanged,
    super.key,
  });

  final MazeLevel difficulty;
  final String playerName;
  final PlayerCharacter character;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<MazeGameScreen> createState() => _MazeGameScreenState();
}

class _MazeGameScreenState extends State<MazeGameScreen>
    with SingleTickerProviderStateMixin {
  final _random = Random();
  final _dice = DiceMovement();
  final _keyboardFocusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  late final AnimationController _diceAnimationController;
  late MazeGrid _maze;
  Point<int> _player = const Point(1, 1);
  List<Point<int>> _enemyPositions = [];
  final List<int> _enemyHealth = [];
  final Set<int> _defeatedEnemies = {};
  final Map<Point<int>, int> _obstacleHealth = {};
  final Map<Point<int>, ObstacleType> _obstacleKinds = {};
  final Set<Point<int>> _destructionEffects = {};
  final Set<Point<int>> _collected = {};
  final Set<Point<int>> _collectedKeys = {};
  WeaponType _equippedWeapon = WeaponType.fireball;
  Point<int> _facing = const Point(0, 1);
  ActiveProjectile? _projectile;
  Timer? _keyboardRepeatTimer;
  bool _isAttacking = false;
  bool _shieldActive = false;
  int _combatRevision = 0;
  int _energy = 100;
  int _darts = 8;
  int _bonusScore = 0;
  DateTime? _shieldExpiresAt;
  DateTime? _shieldReadyAt;
  DateTime? _weaponReadyAt;
  int _moves = 0;
  int _lives = 3;
  int _lanternBattery = 12;
  int _enemyTick = 0;
  int _elapsedSeconds = 0;
  int? _bestTime;
  bool _completed = false;
  bool _paused = false;
  bool _isRolling = false;
  bool _changingLevel = false;
  int _runGeneration = 0;
  bool _victoryDialogShown = false;
  bool _defeatDialogShown = false;
  bool _pauseExitRequested = false;
  late DateTime _startedAt;
  DateTime? _pausedAt;
  DateTime? _lastDamagedAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _diceAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _startRun();
    _loadBestTime();
    unawaited(_prepareAudio());
  }

  Future<void> _prepareAudio() async {
    try {
      await GameAudioService.loadPreferences();
      if (!mounted) return;
      await GameAudioService.startLevel(widget.difficulty);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar el audio: $error')),
        );
      }
    }
  }

  void _advanceEnemies() {
    if (_completed || _paused || _enemyPositions.isEmpty) return;
    final nextPositions = <Point<int>>[];
    // Los enemigos persiguen por los pasillos (sin cruzar muros ni obstáculos)
    // salvo que el jugador esté en la zona segura de inicio.
    final safeZone = bfsDistances(_maze.start, _maze.isWalkable, maxDistance: 3)
        .keys
        .toSet();
    final detectRange = 4 + widget.difficulty.difficulty.index;
    for (var index = 0; index < _maze.enemyPatrols.length; index++) {
      final current = _enemyPositions[index];
      nextPositions.add(
        _defeatedEnemies.contains(index)
            ? current
            : EnemyAI.nextCell(
                current: current,
                patrol: _maze.enemyPatrols[index],
                player: _player,
                passable: _maze.isWalkable,
                detectRange: detectRange,
                safeZone: safeZone,
                taken: nextPositions,
              ),
      );
    }
    setState(() {
      _enemyPositions = nextPositions;
      if (_shieldActive &&
          _shieldExpiresAt != null &&
          DateTime.now().isAfter(_shieldExpiresAt!)) {
        _shieldActive = false;
        _shieldExpiresAt = null;
      }
    });
    if (_enemyPositions.indexWhere((position) => position == _player) >= 0) {
      final enemyIndex = _enemyPositions.indexWhere(
        (position) => position == _player,
      );
      if (!_defeatedEnemies.contains(enemyIndex)) _takeDamage();
    }
  }

  void _takeDamage() {
    final now = DateTime.now();
    if (_completed ||
        _paused ||
        (_lastDamagedAt != null &&
            now.difference(_lastDamagedAt!) < const Duration(seconds: 2))) {
      return;
    }
    if (_shieldActive) {
      setState(() {
        _shieldActive = false;
        _shieldExpiresAt = null;
        _shieldReadyAt = DateTime.now().add(const Duration(seconds: 8));
      });
      unawaited(GameAudioService.playEffect(GameSound.collect));
      return;
    }
    _lastDamagedAt = now;
    unawaited(GameAudioService.playEffect(GameSound.damage));
    setState(() {
      _lives--;
      _player = _maze.start;
      _dice.reset();
    });
    if (_lives == 0) {
      _completed = true;
      _timer?.cancel();
      unawaited(GameAudioService.stopMusic());
      unawaited(_showDefeat());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Un guardián te encontró! Te quedan $_lives vidas.'),
          duration: const Duration(milliseconds: 1100),
        ),
      );
    }
  }

  Future<void> _showDefeat() async {
    if (_defeatDialogShown || !mounted) return;
    _defeatDialogShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.favorite_border_rounded,
          color: Colors.redAccent,
        ),
        title: const Text('Fin de la aventura'),
        content: const Text(
          'Te quedaste sin vidas. ¡Inténtalo de nuevo y encuentra otra ruta!',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _restart();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('REINTENTAR'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _leaveGame();
              },
              icon: const Icon(Icons.home_rounded),
              label: const Text('MENÚ PRINCIPAL'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pauseGame() async {
    if (_paused || _completed) return;
    _paused = true;
    _pressedKeys.clear();
    _keyboardRepeatTimer?.cancel();
    _keyboardRepeatTimer = null;
    _pausedAt = DateTime.now();
    _timer?.cancel();
    _projectile = null;
    _pauseExitRequested = false;
    await GameAudioService.pauseMusic();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.pause_circle_filled_rounded),
        title: const Text('Aventura en pausa'),
        content: const Text('Toma un respiro. El laberinto te espera.'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('CONTINUAR'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _pauseExitRequested = true;
                Navigator.of(dialogContext).pop();
                _restart();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('REINICIAR'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                _pauseExitRequested = true;
                Navigator.of(dialogContext).pop();
                _leaveGame();
              },
              icon: const Icon(Icons.home_rounded),
              label: const Text('MENÚ PRINCIPAL'),
            ),
          ),
        ],
      ),
    );
    if (!mounted || _pauseExitRequested) return;
    final pausedAt = _pausedAt;
    if (pausedAt != null) {
      _startedAt = _startedAt.add(DateTime.now().difference(pausedAt));
    }
    setState(() {
      _paused = false;
      _pausedAt = null;
    });
    _startTimer();
    await GameAudioService.resumeMusic();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _keyboardRepeatTimer?.cancel();
    _keyboardFocusNode.dispose();
    _diceAnimationController.dispose();
    if (!_changingLevel) unawaited(GameAudioService.stopMusic());
    super.dispose();
  }

  void _startRun() {
    _runGeneration++;
    _timer?.cancel();
    _maze = MazeGrid.generate(widget.difficulty);
    _player = _maze.start;
    _collected.clear();
    _collectedKeys.clear();
    _enemyPositions = _maze.enemyPatrols.map((patrol) => patrol.first).toList();
    _enemyHealth
      ..clear()
      ..addAll(
        List<int>.generate(
          _maze.enemyPatrols.length,
          (_) => widget.difficulty.index >= 2 ? 2 : 1,
        ),
      );
    _defeatedEnemies.clear();
    _obstacleKinds
      ..clear()
      ..addAll(_createObstacleKinds());
    _obstacleHealth
      ..clear()
      ..addAll(
        _obstacleKinds.map(
          (position, type) => MapEntry(position, type.durability),
        ),
      );
    _destructionEffects.clear();
    _moves = 0;
    _energy = 100;
    _darts = 8;
    _bonusScore = 0;
    _equippedWeapon = WeaponType.fireball;
    _facing = const Point(0, 1);
    _projectile = null;
    _isAttacking = false;
    _shieldActive = false;
    _shieldExpiresAt = null;
    _shieldReadyAt = null;
    _weaponReadyAt = null;
    _combatRevision++;
    _lives = 3;
    _lanternBattery = 12;
    _enemyTick = 0;
    _elapsedSeconds = 0;
    _completed = false;
    _paused = false;
    _isRolling = false;
    _dice.reset();
    _victoryDialogShown = false;
    _defeatDialogShown = false;
    _pauseExitRequested = false;
    _pausedAt = null;
    _lastDamagedAt = null;
    _startedAt = DateTime.now();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _completed || _paused) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
        if (_shieldActive &&
            _shieldExpiresAt != null &&
            !DateTime.now().isBefore(_shieldExpiresAt!)) {
          _shieldActive = false;
          _shieldExpiresAt = null;
        }
      });
      _enemyTick++;
      if (_enemyTick % 2 == 0) _advanceEnemies();
    });
  }

  Future<void> _loadBestTime() async {
    final bestTime = await StorageService.loadBestTime(widget.difficulty.title);
    if (mounted) setState(() => _bestTime = bestTime);
  }

  void _restart() {
    _keyboardRepeatTimer?.cancel();
    _pressedKeys.clear();
    if (_diceAnimationController.isAnimating) _diceAnimationController.stop();
    _diceAnimationController.value = 0;
    setState(_startRun);
    unawaited(GameAudioService.startLevel(widget.difficulty));
  }

  Future<void> _rollDice() async {
    if (!_dice.canRoll || _isRolling || _completed) return;
    final runGeneration = _runGeneration;
    setState(() => _isRolling = true);
    _diceAnimationController.repeat();
    unawaited(GameAudioService.playEffect(GameSound.diceRoll));
    await Future<void>.delayed(const Duration(milliseconds: 720));
    if (!mounted || runGeneration != _runGeneration) return;
    _diceAnimationController
      ..stop()
      ..value = 0;
    final result = _dice.roll(random: _random);
    setState(() => _isRolling = false);
    if (result != null) {
      unawaited(GameAudioService.playEffect(GameSound.diceResult));
    }
  }

  void _move(int dx, int dy) {
    if (_completed || _paused || _isRolling || _dice.remaining == 0) return;
    _facing = Point(dx, dy);
    final next = Point(_player.x + dx, _player.y + dy);
    if (!_maze.isInside(next) ||
        _maze.walls[next.y][next.x] ||
        _obstacleKinds.containsKey(next)) {
      unawaited(GameAudioService.playEffect(GameSound.wall));
      return;
    }
    if (next == _maze.goal &&
        _collectedKeys.length < widget.difficulty.keyCount) {
      unawaited(GameAudioService.playEffect(GameSound.wall));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La puerta está cerrada: falta una llave.'),
        ),
      );
      return;
    }

    final reachedGoal = next == _maze.goal;
    final collectedStar = _maze.collectibles.contains(next);
    final collectedKey = _maze.keys.contains(next);
    setState(() {
      _player = next;
      _moves++;
      _dice.consume();
      if (collectedStar) _collected.add(next);
      if (collectedKey) _collectedKeys.add(next);
      if (collectedStar) _energy = min(100, _energy + 10);
      if (collectedStar && _darts < 8) _darts++;
      if (widget.difficulty.difficulty == MazeDifficulty.medium) {
        _lanternBattery = max(0, _lanternBattery - 1);
      }
      if (reachedGoal) {
        _completed = true;
        _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
      }
    });
    unawaited(
      GameAudioService.playEffect(
        collectedStar || collectedKey ? GameSound.collect : GameSound.move,
      ),
    );
    final enemyIndex = _enemyPositions.indexWhere(
      (position) => position == next,
    );
    if (enemyIndex >= 0 && !_defeatedEnemies.contains(enemyIndex)) {
      _takeDamage();
    }
    if (reachedGoal) {
      _timer?.cancel();
      unawaited(GameAudioService.stopMusic());
      unawaited(GameAudioService.playEffect(GameSound.victory));
      unawaited(_recordAndShowVictory());
    }
  }

  Future<void> _recordAndShowVictory() async {
    try {
      await StorageService.saveBestTime(
        widget.difficulty.title,
        _elapsedSeconds,
      );
      _bestTime = await StorageService.loadBestTime(widget.difficulty.title);
      await StorageService.recordLevelCompletion(
        levelIndex: widget.difficulty.index,
        stars: _earnedStars,
        score: _score,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el mejor tiempo: $error')),
        );
      }
    }
    if (!mounted || _victoryDialogShown) return;
    _victoryDialogShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _VictoryDialog(
        time: _formattedTime,
        moves: _moves,
        score: _score,
        stars: _earnedStars,
        bestTime: _bestTime,
        hasNextLevel: widget.difficulty.index < MazeLevel.values.length - 1,
        character: widget.character,
        onRestart: () {
          Navigator.of(dialogContext).pop();
          _restart();
        },
        onMenu: () {
          Navigator.of(dialogContext).pop();
          unawaited(GameAudioService.stopMusic());
          Navigator.of(context).pop();
        },
        onNextLevel: () {
          Navigator.of(dialogContext).pop();
          _changingLevel = true;
          final nextIndex = MazeLevel.values.indexOf(widget.difficulty) + 1;
          unawaited(_openNextLevel(MazeLevel.values[nextIndex]));
        },
      ),
    );
  }

  int get _earnedStars {
    final total = _maze.collectibles.length;
    if (total == 0) return 1;
    if (_collected.length >= (total * 0.75).ceil()) return 3;
    if (_collected.length >= (total * 0.4).ceil()) return 2;
    return 1;
  }

  int get _score {
    final baseScore =
        1000 + (MazeLevel.values.indexOf(widget.difficulty) * 800);
    return max(
      0,
      baseScore -
          (_elapsedSeconds * 4) -
          (_moves * 2) +
          (_collected.length * 100) +
          _bonusScore,
    );
  }

  Map<Point<int>, ObstacleType> _createObstacleKinds() {
    final theme = switch (widget.difficulty.index) {
      0 => [ObstacleType.woodenCrate, ObstacleType.thornPlant],
      1 => [
        ObstacleType.web,
        ObstacleType.woodenCrate,
        ObstacleType.magicBarrier,
      ],
      2 => [
        ObstacleType.fragileRock,
        ObstacleType.web,
        ObstacleType.crackedWall,
      ],
      3 => [
        ObstacleType.magicBarrier,
        ObstacleType.magicCrystal,
        ObstacleType.web,
      ],
      _ => [
        ObstacleType.fragileRock,
        ObstacleType.crackedWall,
        ObstacleType.thornPlant,
      ],
    };
    return {
      for (var index = 0; index < _maze.obstacles.length; index++)
        _maze.obstacles.elementAt(index): theme[index % theme.length],
    };
  }

  bool _isWeaponUnlocked(WeaponType weapon) =>
      widget.difficulty.index + 1 >= weapon.unlockLevel;

  void _equipWeapon(WeaponType weapon) {
    if (!_isWeaponUnlocked(weapon) || _completed) return;
    setState(() => _equippedWeapon = weapon);
    unawaited(GameAudioService.playEffect(GameSound.select));
  }

  void _useEquippedWeapon() {
    if (_completed || _paused || _isRolling || _isAttacking) return;
    final now = DateTime.now();
    if (_weaponReadyAt != null && now.isBefore(_weaponReadyAt!)) return;
    switch (_equippedWeapon) {
      case WeaponType.fireball:
        if (_energy < 18) {
          _showCombatMessage('Necesitas 18 puntos de energía para el fuego.');
          return;
        }
        setState(() {
          _energy -= 18;
          _weaponReadyAt = now.add(const Duration(milliseconds: 850));
        });
        unawaited(_launchProjectile(_equippedWeapon, range: 4));
        break;
      case WeaponType.sword:
        setState(() {
          _isAttacking = true;
          _weaponReadyAt = now.add(const Duration(milliseconds: 420));
        });
        _attackCell(_forwardCell(1), _equippedWeapon);
        unawaited(GameAudioService.playEffect(GameSound.move));
        Future<void>.delayed(const Duration(milliseconds: 260), () {
          if (mounted) setState(() => _isAttacking = false);
        });
        break;
      case WeaponType.darts:
        if (_darts == 0) {
          _showCombatMessage(
            'No quedan dardos. Recoge estrellas para reponerlos.',
          );
          return;
        }
        setState(() {
          _darts--;
          _weaponReadyAt = now.add(const Duration(milliseconds: 520));
        });
        unawaited(_launchProjectile(_equippedWeapon, range: 5));
        break;
      case WeaponType.lightning:
        if (_energy < 28) {
          _showCombatMessage('Necesitas 28 puntos de energía para el rayo.');
          return;
        }
        setState(() {
          _energy -= 28;
          _weaponReadyAt = now.add(const Duration(milliseconds: 1300));
        });
        unawaited(_launchProjectile(_equippedWeapon, range: 4));
        break;
    }
  }

  Point<int> _forwardCell(int distance) =>
      Point(_player.x + _facing.x * distance, _player.y + _facing.y * distance);

  Future<void> _launchProjectile(
    WeaponType weapon, {
    required int range,
  }) async {
    final runGeneration = _runGeneration;
    final origin = _player;
    final direction = _facing;
    unawaited(GameAudioService.playEffect(GameSound.diceResult));
    for (var step = 1; step <= range; step++) {
      if (!mounted ||
          runGeneration != _runGeneration ||
          _paused ||
          _completed) {
        return;
      }
      final target = Point(
        origin.x + direction.x * step,
        origin.y + direction.y * step,
      );
      if (!_maze.isInside(target) || _maze.walls[target.y][target.x]) break;
      final obstacle = _obstacleKinds[target];
      if (obstacle != null) {
        setState(
          () => _projectile = ActiveProjectile(
            x: target.x,
            y: target.y,
            weapon: weapon,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 90));
        if (!mounted || runGeneration != _runGeneration) return;
        _attackCell(target, weapon);
        break;
      }
      if (weapon == WeaponType.darts && _maze.keys.contains(target)) {
        setState(() => _collectedKeys.add(target));
        unawaited(GameAudioService.playEffect(GameSound.collect));
        _showCombatMessage('¡Dardo activó el mecanismo y recogió la llave!');
        break;
      }
      setState(
        () => _projectile = ActiveProjectile(
          x: target.x,
          y: target.y,
          weapon: weapon,
        ),
      );
      final enemyIndex = _enemyPositions.indexWhere(
        (position) => position == target,
      );
      if (enemyIndex >= 0 && !_defeatedEnemies.contains(enemyIndex)) {
        if (weapon != WeaponType.darts || widget.difficulty.index < 2) {
          _damageEnemy(enemyIndex);
        }
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 105));
    }
    if (mounted && runGeneration == _runGeneration) {
      setState(() => _projectile = null);
    }
  }

  void _attackCell(Point<int> cell, WeaponType weapon) {
    final obstacle = _obstacleKinds[cell];
    if (obstacle != null) {
      if (!obstacle.canBeDamagedBy(weapon)) {
        _showCombatMessage('${obstacle.label}: este poder no puede dañarlo.');
        return;
      }
      final health = (_obstacleHealth[cell] ?? obstacle.durability) - 1;
      if (health > 0) {
        setState(() {
          _obstacleHealth[cell] = health;
          _combatRevision++;
        });
        unawaited(GameAudioService.playEffect(GameSound.wall));
        return;
      }
      setState(() {
        _obstacleHealth.remove(cell);
        _obstacleKinds.remove(cell);
        _combatRevision++;
        _bonusScore += 40;
        _energy = min(100, _energy + 8);
        _destructionEffects.add(cell);
      });
      final runGeneration = _runGeneration;
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (mounted && runGeneration == _runGeneration) {
          setState(() => _destructionEffects.remove(cell));
        }
      });
      unawaited(GameAudioService.playEffect(GameSound.collect));
      _showCombatMessage(
        '${obstacle.label} destruido: +40 puntos, +8 energía.',
      );
      return;
    }
    final enemyIndex = _enemyPositions.indexWhere(
      (position) => position == cell,
    );
    if (enemyIndex >= 0) _damageEnemy(enemyIndex);
  }

  void _damageEnemy(int index) {
    if (_defeatedEnemies.contains(index) || index >= _enemyHealth.length) {
      return;
    }
    setState(() {
      _enemyHealth[index]--;
      if (_enemyHealth[index] <= 0) {
        _defeatedEnemies.add(index);
        _bonusScore += 100;
        _energy = min(100, _energy + 10);
      }
    });
    unawaited(GameAudioService.playEffect(GameSound.damage));
  }

  void _activateShield() {
    if (_completed || _paused || _shieldActive) return;
    if (widget.difficulty.index < 1) {
      _showCombatMessage('El escudo se desbloquea al llegar al nivel 2.');
      return;
    }
    final now = DateTime.now();
    if (_shieldReadyAt != null && now.isBefore(_shieldReadyAt!)) return;
    if (_energy < 25) {
      _showCombatMessage('Necesitas 25 puntos de energía para el escudo.');
      return;
    }
    final expiresAt = now.add(const Duration(seconds: 4));
    setState(() {
      _energy -= 25;
      _shieldActive = true;
      _shieldExpiresAt = expiresAt;
      _shieldReadyAt = now.add(const Duration(seconds: 10));
    });
    unawaited(GameAudioService.playEffect(GameSound.collect));
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted && _shieldActive && _shieldExpiresAt == expiresAt) {
        setState(() {
          _shieldActive = false;
          _shieldExpiresAt = null;
        });
      }
    });
  }

  void _interact() {
    if (_completed || _paused) return;
    final adjacentCells = [
      _forwardCell(1),
      Point(_player.x + 1, _player.y),
      Point(_player.x - 1, _player.y),
      Point(_player.x, _player.y + 1),
      Point(_player.x, _player.y - 1),
    ];
    for (final cell in adjacentCells) {
      if (_maze.keys.contains(cell) && _collectedKeys.add(cell)) {
        setState(() {});
        unawaited(GameAudioService.playEffect(GameSound.collect));
        _showCombatMessage('Llave recogida. La salida ya puede abrirse.');
        return;
      }
      if (_obstacleKinds[cell] == ObstacleType.magicBarrier &&
          _equippedWeapon == WeaponType.lightning) {
        _attackCell(cell, _equippedWeapon);
        return;
      }
    }
    if (_player == _maze.goal &&
        _collectedKeys.length >= widget.difficulty.keyCount) {
      _finishAtGoal();
      return;
    }
    _showCombatMessage('No hay nada con lo que interactuar cerca.');
  }

  void _finishAtGoal() {
    if (_completed || _collectedKeys.length < widget.difficulty.keyCount) {
      return;
    }
    setState(() {
      _completed = true;
      _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
    });
    _timer?.cancel();
    unawaited(GameAudioService.stopMusic());
    unawaited(GameAudioService.playEffect(GameSound.victory));
    unawaited(_recordAndShowVictory());
  }

  void _showCombatMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1200),
        ),
      );
  }

  String get _formattedTime =>
      '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}';

  void _handleSwipe(DragEndDetails details) {
    if (_paused) return;
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance < 160) return;
    if (velocity.dx.abs() > velocity.dy.abs()) {
      _move(velocity.dx > 0 ? 1 : -1, 0);
    } else {
      _move(0, velocity.dy > 0 ? 1 : -1);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
      if (!_pressedKeys.any(_isMovementKey)) {
        _keyboardRepeatTimer?.cancel();
        _keyboardRepeatTimer = null;
      }
      return;
    }
    if (event is! KeyDownEvent || !_pressedKeys.add(event.logicalKey)) return;
    if (_isMovementKey(event.logicalKey)) {
      _moveForKey(event.logicalKey);
      _keyboardRepeatTimer ??= Timer.periodic(
        const Duration(milliseconds: 190),
        (_) {
          if (!mounted || _paused || _completed || _pressedKeys.isEmpty) return;
          final movementKey = _pressedKeys.lastWhere(_isMovementKey);
          _moveForKey(movementKey);
        },
      );
      return;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _useEquippedWeapon();
        break;
      case LogicalKeyboardKey.keyR:
        unawaited(_rollDice());
        break;
      case LogicalKeyboardKey.keyE:
        _interact();
        break;
      case LogicalKeyboardKey.shiftLeft:
      case LogicalKeyboardKey.shiftRight:
        _activateShield();
        break;
      case LogicalKeyboardKey.digit1:
        _equipWeapon(WeaponType.fireball);
        break;
      case LogicalKeyboardKey.digit2:
        _equipWeapon(WeaponType.sword);
        break;
      case LogicalKeyboardKey.digit3:
        _equipWeapon(WeaponType.darts);
        break;
      case LogicalKeyboardKey.digit4:
        _equipWeapon(WeaponType.lightning);
        break;
      case LogicalKeyboardKey.escape:
        unawaited(_pauseGame());
        break;
      default:
        break;
    }
  }

  bool _isMovementKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.keyW ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.keyS ||
      key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.keyA ||
      key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.keyD;

  void _moveForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      _move(0, -1);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      _move(0, 1);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyA) {
      _move(-1, 0);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      _move(1, 0);
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
          onThemeChanged: widget.onThemeChanged,
          onAudioChanged: (preferences) => GameAudioService.updatePreferences(
            preferences,
            currentLevel: widget.difficulty,
          ),
        ),
      ),
    );
  }

  Future<void> _openNextLevel(MazeLevel level) async {
    await GameAudioService.stopMusic();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MazeGameScreen(
          difficulty: level,
          playerName: widget.playerName,
          character: widget.character,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );
  }

  void _leaveGame() {
    unawaited(GameAudioService.stopMusic());
    Navigator.of(context).pop();
  }

  Widget _buildMazeBoard(double boardSize, WorldTheme world) {
    return SizedBox(
      key: const ValueKey('maze-board'),
      width: boardSize,
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanEnd: _handleSwipe,
          child: LayoutBuilder(
            builder: (context, boardConstraints) {
              final cellSize = boardConstraints.maxWidth / _maze.size;
              return Container(
                decoration: BoxDecoration(
                  color: world.wall,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: world.accent, width: 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MazePainter(
                          maze: _maze,
                          collected: _collected,
                          collectedKeys: _collectedKeys,
                          obstacles: Map.of(_obstacleKinds),
                          obstacleHealth: Map.of(_obstacleHealth),
                          combatRevision: _combatRevision,
                          doorLocked:
                              widget.difficulty.requiresKey &&
                              _collectedKeys.length <
                                  widget.difficulty.keyCount,
                          player: _player,
                          lanternLit: _lanternBattery > 0,
                          world: world,
                        ),
                      ),
                    ),
                    for (var index = 0; index < _enemyPositions.length; index++)
                      AnimatedPositioned(
                        key: ValueKey('enemy-$index'),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeInOut,
                        left: _enemyPositions[index].x * cellSize,
                        top: _enemyPositions[index].y * cellSize,
                        width: cellSize,
                        height: cellSize,
                        child: AnimatedOpacity(
                          opacity: _defeatedEnemies.contains(index) ? 0 : 1,
                          duration: const Duration(milliseconds: 250),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Center(
                                  child: _EnemyAvatar(
                                    level: widget.difficulty,
                                    world: world,
                                    size: cellSize * 0.68,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: cellSize * 0.7,
                                child: LinearProgressIndicator(
                                  value:
                                      _enemyHealth[index] /
                                      (widget.difficulty.index >= 2 ? 2 : 1),
                                  minHeight: 2,
                                  color: Colors.redAccent,
                                  backgroundColor: Colors.black26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 135),
                      curve: Curves.easeOutCubic,
                      left: _player.x * cellSize,
                      top: _player.y * cellSize,
                      width: cellSize,
                      height: cellSize,
                      child: Padding(
                        padding: EdgeInsets.all(cellSize * 0.12),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            if (_shieldActive)
                              Container(
                                width: cellSize * 0.96,
                                height: cellSize * 0.96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.cyan.withValues(alpha: 0.25),
                                  border: Border.all(
                                    color: Colors.cyanAccent,
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.cyanAccent,
                                      blurRadius: 9,
                                    ),
                                  ],
                                ),
                              ),
                            CharacterAvatar(
                              character: widget.character,
                              size: cellSize * 0.82,
                              backgroundColor: world.floor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_projectile != null)
                      AnimatedPositioned(
                        key: const ValueKey('projectile'),
                        duration: const Duration(milliseconds: 80),
                        curve: Curves.linear,
                        left: _projectile!.x * cellSize,
                        top: _projectile!.y * cellSize,
                        width: cellSize,
                        height: cellSize,
                        child: Center(
                          child: Text(
                            _projectile!.weapon.symbol,
                            style: TextStyle(
                              fontSize: cellSize * 0.72,
                              color: switch (_projectile!.weapon) {
                                WeaponType.fireball => Colors.deepOrangeAccent,
                                WeaponType.sword => Colors.lightBlueAccent,
                                WeaponType.darts => Colors.white,
                                WeaponType.lightning => Colors.cyanAccent,
                              },
                              shadows: const [
                                Shadow(color: Colors.deepOrange, blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    for (final effect in _destructionEffects)
                      Positioned(
                        key: ValueKey('impact-$effect'),
                        left: effect.x * cellSize,
                        top: effect.y * cellSize,
                        width: cellSize,
                        height: cellSize,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.35, end: 1.3),
                          duration: const Duration(milliseconds: 300),
                          builder: (context, scale, child) => Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: (1 - scale / 1.3).clamp(0, 1),
                              child: child,
                            ),
                          ),
                          child: const Center(
                            child: Text('💥', style: TextStyle(fontSize: 24)),
                          ),
                        ),
                      ),
                    if (_isAttacking)
                      Positioned(
                        left: _forwardCell(1).x * cellSize,
                        top: _forwardCell(1).y * cellSize,
                        width: cellSize,
                        height: cellSize,
                        child: Center(
                          child: Text(
                            '⚔️',
                            style: TextStyle(
                              fontSize: cellSize * 0.72,
                              shadows: const [
                                Shadow(color: Colors.white, blurRadius: 10),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCombatPanel(GameColors colors) {
    return _CombatPanel(
      weapon: _equippedWeapon,
      unlocked: {
        for (final weapon in WeaponType.values)
          weapon: _isWeaponUnlocked(weapon),
      },
      energy: _energy,
      darts: _darts,
      weaponReadyAt: _weaponReadyAt,
      shieldReadyAt: _shieldReadyAt,
      shieldActive: _shieldActive,
      shieldUnlocked: widget.difficulty.index >= 1,
      isAttacking: _isAttacking,
      onEquip: _equipWeapon,
      onAttack: _useEquippedWeapon,
      onShield: _activateShield,
      onInteract: _interact,
    );
  }

  Widget _buildObjective(WorldTheme world) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          widget.difficulty.objective,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: world.wall,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (widget.difficulty.difficulty == MazeDifficulty.medium) ...[
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flashlight_on_rounded,
                color: _lanternBattery > 0 ? world.secondary : world.wall,
                size: 17,
              ),
              const SizedBox(width: 4),
              Text(
                'Linterna $_lanternBattery',
                style: TextStyle(
                  color: world.wall,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMovementControls(GameColors colors) {
    return Column(
      children: [
        const SizedBox(height: 12),
        _DicePanel(
          result: _dice.result,
          remaining: _dice.remaining,
          used: _dice.used,
          isRolling: _isRolling,
          animation: _diceAnimationController,
          onRoll: _rollDice,
        ),
        const SizedBox(height: 12),
        _DirectionPad(
          onMove: _move,
          enabled: _dice.remaining > 0 && !_isRolling && !_completed,
        ),
        const SizedBox(height: 6),
        Text(
          'WASD / flechas: mover · Espacio: poder · R: dado · E: interactuar · Shift: escudo · Esc: pausa',
          style: TextStyle(color: colors.muted, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    final world = WorldTheme.forLevel(
      widget.difficulty,
      darkMode: Theme.of(context).brightness == Brightness.dark,
    );
    final levelNumber = MazeLevel.values.indexOf(widget.difficulty) + 1;
    return Scaffold(
      backgroundColor: world.background,
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final landscape =
                  MediaQuery.orientationOf(context) == Orientation.landscape &&
                  constraints.maxWidth > constraints.maxHeight;
              final widthLimit = min(constraints.maxWidth - 36, 1184.0);
              final boardSize = landscape
                  ? min(
                      min(widthLimit * 0.52, constraints.maxHeight * 0.72),
                      520.0,
                    )
                  : min(min(widthLimit, constraints.maxHeight * 0.3), 520.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: landscape ? 1220 : 560,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Volver al menú',
                              onPressed: _leaveGame,
                              icon: const Icon(Icons.arrow_back_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: colors.surface,
                                foregroundColor: colors.ink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NIVEL $levelNumber · ${widget.difficulty.title.toUpperCase()}',
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    '¡Vamos, ${widget.playerName}!',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.ink,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    widget.difficulty.tagline,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: world.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Pausar partida',
                              onPressed: _pauseGame,
                              icon: const Icon(Icons.pause_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: world.surface,
                                foregroundColor: colors.ink,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Configuración',
                              onPressed: _openSettings,
                              icon: const Icon(Icons.tune_rounded),
                            ),
                            IconButton(
                              tooltip: 'Reintentar nivel',
                              onPressed: _restart,
                              icon: const Icon(Icons.refresh_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: colors.surface,
                                foregroundColor: colors.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatTile(
                                icon: Icons.timer_outlined,
                                label: 'TIEMPO',
                                value: _formattedTime,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _StatTile(
                                icon: Icons.stars_rounded,
                                label: 'PUNTOS',
                                value: '$_score',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _StatTile(
                                icon: Icons.favorite_rounded,
                                label: 'VIDAS',
                                value: '$_lives/3',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _StatTile(
                                icon: Icons.star_rounded,
                                label: 'ESTRELLAS',
                                value:
                                    '${_collected.length}/${_maze.collectibles.length}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_walk_rounded,
                              color: world.wall,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Movimientos $_moves',
                              key: const ValueKey('move-count'),
                              style: TextStyle(
                                color: world.wall,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (widget.difficulty.requiresKey) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.key_rounded,
                                color: world.secondary,
                                size: 15,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Llaves ${_collectedKeys.length}/${widget.difficulty.keyCount}',
                                style: TextStyle(
                                  color: world.wall,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (landscape) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  children: [
                                    _buildMazeBoard(boardSize, world),
                                    _buildObjective(world),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildCombatPanel(colors),
                                    _buildMovementControls(colors),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          _buildCombatPanel(colors),
                          const SizedBox(height: 14),
                          _buildMazeBoard(boardSize, world),
                          _buildObjective(world),
                          _buildMovementControls(colors),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: colors.coral),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
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

class _CombatPanel extends StatelessWidget {
  const _CombatPanel({
    required this.weapon,
    required this.unlocked,
    required this.energy,
    required this.darts,
    required this.weaponReadyAt,
    required this.shieldReadyAt,
    required this.shieldActive,
    required this.shieldUnlocked,
    required this.isAttacking,
    required this.onEquip,
    required this.onAttack,
    required this.onShield,
    required this.onInteract,
  });

  final WeaponType weapon;
  final Map<WeaponType, bool> unlocked;
  final int energy;
  final int darts;
  final DateTime? weaponReadyAt;
  final DateTime? shieldReadyAt;
  final bool shieldActive;
  final bool shieldUnlocked;
  final bool isAttacking;
  final ValueChanged<WeaponType> onEquip;
  final VoidCallback onAttack;
  final VoidCallback onShield;
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    final attackCooldown = _remainingSeconds(weaponReadyAt);
    final shieldCooldown = _remainingSeconds(shieldReadyAt);
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'PODERES · 1—4 EQUIPAR',
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${weapon.symbol} ${weapon.label}',
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in WeaponType.values)
                  InkWell(
                    onTap: unlocked[item]! ? () => onEquip(item) : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 72),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: item == weapon
                            ? colors.forest
                            : colors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: item == weapon
                              ? colors.mint
                              : colors.muted.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${item.index + 1} ${item.symbol}',
                            style: TextStyle(
                              color: item == weapon
                                  ? colors.mint
                                  : unlocked[item]!
                                  ? colors.ink
                                  : colors.muted,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            unlocked[item]!
                                ? item.label
                                : 'Nivel ${item.unlockLevel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: item == weapon
                                  ? colors.background
                                  : colors.muted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.bolt_rounded, color: colors.coral, size: 17),
                const SizedBox(width: 4),
                Text(
                  'Energía $energy/100',
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: energy / 100,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(99),
                    color: colors.mint,
                    backgroundColor: colors.muted.withValues(alpha: 0.18),
                  ),
                ),
                if (weapon == WeaponType.darts) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Dardos $darts',
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isAttacking ? null : onAttack,
                    icon: Text(weapon.symbol),
                    label: Text(
                      attackCooldown > 0
                          ? 'RECARGA ${attackCooldown}s'
                          : 'ATACAR · ESPACIO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        shieldActive || shieldCooldown > 0 || !shieldUnlocked
                        ? null
                        : onShield,
                    icon: const Icon(Icons.shield_rounded, size: 17),
                    label: Text(
                      !shieldUnlocked
                          ? 'ESCUDO · NIVEL 2'
                          : shieldActive
                          ? 'ESCUDO ACTIVO'
                          : shieldCooldown > 0
                          ? 'ESCUDO ${shieldCooldown}s'
                          : 'ESCUDO · SHIFT',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Interactuar (E)',
                  onPressed: onInteract,
                  icon: const Icon(Icons.touch_app_rounded),
                ),
              ],
            ),
            Text(
              'Fuego: 18 energía · Rayo: 28 · Escudo: 25 · Dardos: $darts',
              style: TextStyle(color: colors.muted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  int _remainingSeconds(DateTime? readyAt) {
    if (readyAt == null) return 0;
    return max(
      0,
      (readyAt.difference(DateTime.now()).inMilliseconds / 1000).ceil(),
    );
  }
}

class _DicePanel extends StatelessWidget {
  const _DicePanel({
    required this.result,
    required this.remaining,
    required this.used,
    required this.isRolling,
    required this.animation,
    required this.onRoll,
  });

  final int? result;
  final int remaining;
  final int used;
  final bool isRolling;
  final Animation<double> animation;
  final VoidCallback onRoll;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    final canRoll = remaining == 0 && !isRolling;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Semantics(
                  label: result == null
                      ? 'Dado listo para lanzar'
                      : 'Resultado del dado: $result',
                  child: RotationTransition(
                    turns: animation,
                    child: DiceFace(value: result ?? 1, color: colors.forest),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RESULTADO DEL DADO',
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        result?.toString() ?? '—',
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Restantes: $remaining   ·   Usados: $used',
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canRoll ? onRoll : null,
                icon: Icon(
                  isRolling ? Icons.casino_rounded : Icons.casino_outlined,
                ),
                label: Text(
                  isRolling
                      ? 'LANZANDO...'
                      : canRoll
                      ? 'LANZAR DADO'
                      : 'AVANZA $remaining CASILLAS',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionPad extends StatelessWidget {
  const _DirectionPad({required this.onMove, required this.enabled});

  final void Function(int, int) onMove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DirectionButton(
          icon: Icons.keyboard_arrow_up_rounded,
          label: 'Arriba',
          enabled: enabled,
          onPressed: () => onMove(0, -1),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DirectionButton(
              icon: Icons.keyboard_arrow_left_rounded,
              label: 'Izquierda',
              enabled: enabled,
              onPressed: () => onMove(-1, 0),
            ),
            const SizedBox(width: 8),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.ink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.control_camera_rounded,
                color: colors.mint,
                size: 22,
              ),
            ),
            const SizedBox(width: 8),
            _DirectionButton(
              icon: Icons.keyboard_arrow_right_rounded,
              label: 'Derecha',
              enabled: enabled,
              onPressed: () => onMove(1, 0),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _DirectionButton(
          icon: Icons.keyboard_arrow_down_rounded,
          label: 'Abajo',
          enabled: enabled,
          onPressed: () => onMove(0, 1),
        ),
      ],
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.enabled,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return SizedBox(
      width: 52,
      height: 52,
      child: IconButton.filled(
        tooltip: label,
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 31),
        style: IconButton.styleFrom(
          backgroundColor: colors.surface,
          foregroundColor: colors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _EnemyAvatar extends StatefulWidget {
  const _EnemyAvatar({
    required this.level,
    required this.world,
    required this.size,
  });

  final MazeLevel level;
  final WorldTheme world;
  final double size;

  @override
  State<_EnemyAvatar> createState() => _EnemyAvatarState();
}

class _EnemyAvatarState extends State<_EnemyAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.9,
      upperBound: 1.08,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.level.difficulty == MazeDifficulty.easy ||
        widget.level.difficulty == MazeDifficulty.medium) {
      return Center(
        child: CharacterAvatar(
          character: PlayerCharacter.ghost,
          size: widget.size,
          backgroundColor: widget.world.floor,
        ),
      );
    }
    final icon = switch (widget.level.difficulty) {
      MazeDifficulty.hard => Icons.account_tree_rounded,
      MazeDifficulty.expert => Icons.smart_toy_rounded,
      MazeDifficulty.extreme => Icons.local_fire_department_rounded,
      MazeDifficulty.easy || MazeDifficulty.medium => Icons.face_rounded,
    };
    return Center(
      child: ScaleTransition(
        scale: _pulse,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.world.surface,
            shape: BoxShape.circle,
            border: Border.all(color: widget.world.secondary, width: 2),
          ),
          child: Icon(
            icon,
            color: widget.world.accent,
            size: widget.size * 0.72,
          ),
        ),
      ),
    );
  }
}

class _VictoryDialog extends StatelessWidget {
  const _VictoryDialog({
    required this.time,
    required this.moves,
    required this.score,
    required this.stars,
    required this.bestTime,
    required this.hasNextLevel,
    required this.character,
    required this.onRestart,
    required this.onMenu,
    required this.onNextLevel,
  });

  final String time;
  final int moves;
  final int score;
  final int stars;
  final int? bestTime;
  final bool hasNextLevel;
  final PlayerCharacter character;
  final VoidCallback onRestart;
  final VoidCallback onMenu;
  final VoidCallback onNextLevel;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return AlertDialog(
      icon: Icon(Icons.emoji_events_rounded, color: colors.coral, size: 42),
      title: Text(
        '¡Felicidades!',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.ink, fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CharacterAvatar(
            character: character,
            size: 66,
            backgroundColor: colors.surface,
          ),
          const Text(
            '¡Has completado el laberinto!',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < 3; index++)
                Icon(
                  index < stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: colors.coral,
                  size: 30,
                ),
            ],
          ),
          _ResultLine(label: 'Tiempo empleado', value: time),
          _ResultLine(label: 'Movimientos', value: '$moves'),
          _ResultLine(label: 'Puntuación', value: '$score'),
          if (bestTime != null)
            _ResultLine(
              label: 'Mejor tiempo',
              value:
                  '${(bestTime! ~/ 60).toString().padLeft(2, '0')}:${(bestTime! % 60).toString().padLeft(2, '0')}',
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: hasNextLevel ? onNextLevel : onMenu,
            child: Text(hasNextLevel ? 'SIGUIENTE NIVEL' : 'VOLVER AL MENÚ'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('REINTENTAR'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: onMenu,
            icon: const Icon(Icons.home_rounded),
            label: const Text('MENÚ PRINCIPAL'),
          ),
        ),
      ],
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: colors.muted)),
          ),
          Text(
            value,
            style: TextStyle(color: colors.ink, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _MazePainter extends CustomPainter {
  const _MazePainter({
    required this.maze,
    required this.collected,
    required this.collectedKeys,
    required this.obstacles,
    required this.obstacleHealth,
    required this.combatRevision,
    required this.doorLocked,
    required this.player,
    required this.lanternLit,
    required this.world,
  });

  final MazeGrid maze;
  final Set<Point<int>> collected;
  final Set<Point<int>> collectedKeys;
  final Map<Point<int>, ObstacleType> obstacles;
  final Map<Point<int>, int> obstacleHealth;
  final int combatRevision;
  final bool doorLocked;
  final Point<int> player;
  final bool lanternLit;
  final WorldTheme world;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / maze.size;
    final cellHeight = size.height / maze.size;
    final wallPaint = Paint()..color = world.wall;
    final floorPaint = Paint();
    for (var y = 0; y < maze.size; y++) {
      for (var x = 0; x < maze.size; x++) {
        final rect = Rect.fromLTWH(
          x * cellWidth + 0.35,
          y * cellHeight + 0.35,
          cellWidth - 0.7,
          cellHeight - 0.7,
        );
        if (maze.walls[y][x]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cellWidth * 0.12)),
            wallPaint,
          );
        } else {
          floorPaint.color = (x + y).isEven
              ? world.floor
              : world.floorAlternate;
          canvas.drawRect(rect, floorPaint);
        }
      }
    }

    final startCenter = Offset(cellWidth * 1.5, cellHeight * 1.5);
    final goalCenter = Offset(
      cellWidth * (maze.size - 1.5),
      cellHeight * (maze.size - 1.5),
    );
    canvas.drawCircle(
      startCenter,
      cellWidth * 0.2,
      Paint()..color = world.accent,
    );
    canvas.drawCircle(
      startCenter,
      cellWidth * 0.09,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      goalCenter,
      cellWidth * 0.34,
      Paint()..color = world.secondary,
    );
    canvas.drawCircle(
      goalCenter,
      cellWidth * 0.23,
      Paint()..color = world.accent,
    );
    final flag = Path()
      ..moveTo(
        goalCenter.dx - cellWidth * 0.1,
        goalCenter.dy + cellWidth * 0.16,
      )
      ..lineTo(
        goalCenter.dx - cellWidth * 0.1,
        goalCenter.dy - cellWidth * 0.17,
      )
      ..lineTo(
        goalCenter.dx + cellWidth * 0.2,
        goalCenter.dy - cellWidth * 0.08,
      )
      ..lineTo(
        goalCenter.dx - cellWidth * 0.1,
        goalCenter.dy + cellWidth * 0.02,
      )
      ..close();
    canvas.drawPath(flag, Paint()..color = world.wall);
    if (doorLocked) {
      final lockPainter = TextPainter(
        text: TextSpan(
          text: '🔒',
          style: TextStyle(fontSize: cellWidth * 0.42),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      lockPainter.paint(
        canvas,
        Offset(
          goalCenter.dx - lockPainter.width / 2,
          goalCenter.dy - lockPainter.height / 2,
        ),
      );
    }

    for (final collectible in maze.collectibles.difference(collected)) {
      final center = Offset(
        (collectible.x + 0.5) * cellWidth,
        (collectible.y + 0.5) * cellHeight,
      );
      final radius = cellWidth * 0.22;
      final star = Path();
      for (var point = 0; point < 10; point++) {
        final angle = -pi / 2 + (pi * point / 5);
        final currentRadius = point.isEven ? radius : radius * 0.46;
        final position = Offset(
          center.dx + cos(angle) * currentRadius,
          center.dy + sin(angle) * currentRadius,
        );
        if (point == 0) {
          star.moveTo(position.dx, position.dy);
        } else {
          star.lineTo(position.dx, position.dy);
        }
      }
      star.close();
      canvas.drawPath(star, Paint()..color = world.secondary);
      canvas.drawCircle(center, radius * 0.13, Paint()..color = Colors.white);
    }

    for (final key in maze.keys.difference(collectedKeys)) {
      final center = Offset(
        (key.x + 0.5) * cellWidth,
        (key.y + 0.5) * cellHeight,
      );
      final keyPaint = Paint()
        ..color = world.secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, cellWidth * 0.11)
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(
        center.translate(-cellWidth * 0.12, -cellHeight * 0.08),
        cellWidth * 0.17,
        keyPaint,
      );
      canvas.drawLine(
        center.translate(cellWidth * 0.03, cellHeight * 0.03),
        center.translate(cellWidth * 0.26, cellHeight * 0.26),
        keyPaint,
      );
      canvas.drawLine(
        center.translate(cellWidth * 0.14, cellHeight * 0.15),
        center.translate(cellWidth * 0.25, cellHeight * 0.04),
        keyPaint,
      );
    }

    for (final entry in obstacles.entries) {
      final obstacle = entry.key;
      final center = Offset(
        (obstacle.x + 0.5) * cellWidth,
        (obstacle.y + 0.5) * cellHeight,
      );
      _paintObstacle(
        canvas,
        center,
        cellWidth,
        entry.value,
        obstacleHealth[obstacle] ?? entry.value.durability,
      );
    }

    if (maze.keys.isNotEmpty && !lanternLit) {
      final bounds = Path()..addRect(Offset.zero & size);
      final light = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(
              (player.x + 0.5) * cellWidth,
              (player.y + 0.5) * cellHeight,
            ),
            radius: cellWidth * 2.4,
          ),
        );
      final shadow = Path.combine(PathOperation.difference, bounds, light);
      canvas.drawPath(shadow, Paint()..color = const Color(0xE6131020));
    }
  }

  void _paintObstacle(
    Canvas canvas,
    Offset center,
    double cellSize,
    ObstacleType type,
    int health,
  ) {
    final color = switch (type) {
      ObstacleType.woodenCrate => const Color(0xFF9B6038),
      ObstacleType.web => const Color(0xFFB4B0C7),
      ObstacleType.fragileRock ||
      ObstacleType.crackedWall => const Color(0xFF847F78),
      ObstacleType.magicBarrier => const Color(0xFF8A59C6),
      ObstacleType.thornPlant => const Color(0xFF398A50),
      ObstacleType.magicCrystal => const Color(0xFF36BFD2),
      ObstacleType.lockedDoor => const Color(0xFF7C3A4B),
    };
    final box = Rect.fromCenter(
      center: center,
      width: cellSize * 0.72,
      height: cellSize * 0.72,
    );
    final paint = Paint()..color = color;
    if (type == ObstacleType.fragileRock ||
        type == ObstacleType.thornPlant ||
        type == ObstacleType.magicCrystal) {
      final diamond = Path()
        ..moveTo(center.dx, box.top)
        ..lineTo(box.right, center.dy)
        ..lineTo(center.dx, box.bottom)
        ..lineTo(box.left, center.dy)
        ..close();
      canvas.drawPath(diamond, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, Radius.circular(cellSize * 0.1)),
        paint,
      );
    }
    final symbolPainter = TextPainter(
      text: TextSpan(
        text: type.symbol,
        style: TextStyle(
          color: Colors.white,
          fontSize: cellSize * 0.48,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: cellSize);
    symbolPainter.paint(
      canvas,
      Offset(
        center.dx - symbolPainter.width / 2,
        center.dy - symbolPainter.height / 2,
      ),
    );
    if (health < type.durability) {
      final crack = Paint()
        ..color = Colors.white
        ..strokeWidth = max(1, cellSize * 0.045)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center.translate(-cellSize * 0.15, -cellSize * 0.12),
        center.translate(cellSize * 0.02, cellSize * 0.02),
        crack,
      );
      canvas.drawLine(
        center.translate(cellSize * 0.02, cellSize * 0.02),
        center.translate(-cellSize * 0.05, cellSize * 0.18),
        crack,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MazePainter oldDelegate) =>
      oldDelegate.maze != maze ||
      oldDelegate.collected.length != collected.length ||
      oldDelegate.collectedKeys.length != collectedKeys.length ||
      oldDelegate.combatRevision != combatRevision ||
      oldDelegate.doorLocked != doorLocked ||
      oldDelegate.player != player ||
      oldDelegate.lanternLit != lanternLit ||
      oldDelegate.world != world;
}
