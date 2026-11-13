enum PlayerCharacter {
  chomper('chomper', 'Chispa'),
  ghost('ghost', 'Fantasmín'),
  ball('ball', 'Pelota'),
  penguin('penguin', 'Pingüi');

  const PlayerCharacter(this.storageKey, this.displayName);

  final String storageKey;
  final String displayName;

  static PlayerCharacter fromStorage(String? key) {
    for (final character in PlayerCharacter.values) {
      if (character.storageKey == key) return character;
    }
    return PlayerCharacter.chomper;
  }
}
