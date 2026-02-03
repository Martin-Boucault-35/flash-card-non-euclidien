/// État du jeu
enum GameState {
  setup,
  playing,
  finished,
}

/// Configuration d'une partie
class GameConfig {
  final List<String> themes;
  final int questionCount;

  GameConfig({
    this.themes = const [],
    this.questionCount = 5,
  });

  GameConfig copyWith({
    List<String>? themes,
    int? questionCount,
  }) {
    return GameConfig(
      themes: themes ?? List.from(this.themes),
      questionCount: questionCount ?? this.questionCount,
    );
  }
}
