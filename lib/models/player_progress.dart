class PlayerProgress {
  const PlayerProgress({
    required this.highestUnlockedLevel,
    required this.totalStars,
    required this.completedLevels,
    required this.starsByLevel,
    required this.bestScores,
  });

  const PlayerProgress.empty()
    : highestUnlockedLevel = 0,
      totalStars = 0,
      completedLevels = const {},
      starsByLevel = const {},
      bestScores = const {};

  final int highestUnlockedLevel;
  final int totalStars;
  final Set<int> completedLevels;
  final Map<int, int> starsByLevel;
  final Map<int, int> bestScores;

  bool isUnlocked(int index) => index <= highestUnlockedLevel;

  int starsForLevel(int index) => starsByLevel[index] ?? 0;

  int bestScoreForLevel(int index) => bestScores[index] ?? 0;
}
