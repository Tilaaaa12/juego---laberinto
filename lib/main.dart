import 'screens/game_screen.dart';

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MazeAdventureApp());
}

class MazeAdventureApp extends StatefulWidget {
  const MazeAdventureApp({super.key});

  @override
  State<MazeAdventureApp> createState() => _MazeAdventureAppState();
}

class _MazeAdventureAppState extends State<MazeAdventureApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final isDarkMode = await StorageService.loadDarkMode();
    if (mounted) setState(() => _isDarkMode = isDarkMode);
  }

  Future<void> _setDarkMode(bool value) async {
    setState(() => _isDarkMode = value);
    await StorageService.saveDarkMode(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(
      _isDarkMode ? Brightness.dark : Brightness.light,
    );
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Maze Adventure',
      theme: ThemeData(
        useMaterial3: true,
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: colors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colors.forest,
          brightness: _isDarkMode ? Brightness.dark : Brightness.light,
          surface: colors.surface,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(54, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      home: HomeScreen(
        onThemeChanged: _setDarkMode,
        isDarkMode: _isDarkMode,
        onStart: (playerName, difficulty, character) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute<void>(
              builder: (_) => MazeGameScreen(
                difficulty: difficulty,
                playerName: playerName,
                character: character,
                onThemeChanged: _setDarkMode,
              ),
            ),
          );
        },
      ),
    );
  }
}
