/// Configuration des intervalles Leitner (en jours)
class LeitnerSettings {
  /// Intervalles par défaut: 1j, 3j, 7j, 14j, 30j, 90j
  static const List<int> defaultIntervals = [1, 3, 7, 14, 30, 90];

  /// Seuil "réponse rapide" par défaut (en secondes) : répondre en dessous
  /// fait monter la carte de +2 boîtes au lieu de +1.
  static const int defaultGoldenSeconds = 5;

  final List<int> intervals;

  /// Temps max (en secondes) pour décrocher le bonus "réponse rapide" (+2 boîtes).
  final int goldenSeconds;

  LeitnerSettings({List<int>? intervals, int? goldenSeconds})
      : intervals = intervals ?? List.from(defaultIntervals),
        goldenSeconds = goldenSeconds ?? defaultGoldenSeconds;

  int get boxCount => intervals.length;

  /// Retourne l'intervalle en jours pour passer de la boîte [box] à la suivante
  int getIntervalDays(int box) {
    if (box < 1 || box > intervals.length) return intervals.last;
    return intervals[box - 1];
  }

  /// Calcule la prochaine date de révision après avoir réussi depuis la boîte [box]
  int computeNextReview(int box) {
    final days = getIntervalDays(box);
    return DateTime.now()
        .add(Duration(days: days))
        .millisecondsSinceEpoch;
  }

  /// Label pour une boîte donnée
  static String boxLabel(int box, int maxBox) {
    if (box > maxBox) return 'Maîtrisé';
    return 'Boîte $box';
  }

  LeitnerSettings copyWith({List<int>? intervals, int? goldenSeconds}) {
    return LeitnerSettings(
      intervals: intervals ?? List.from(this.intervals),
      goldenSeconds: goldenSeconds ?? this.goldenSeconds,
    );
  }

  Map<String, dynamic> toJson() =>
      {'intervals': intervals, 'goldenSeconds': goldenSeconds};

  factory LeitnerSettings.fromJson(Map<String, dynamic> json) {
    return LeitnerSettings(
      intervals: (json['intervals'] as List?)?.cast<int>() ??
          List.from(defaultIntervals),
      goldenSeconds: json['goldenSeconds'] as int? ?? defaultGoldenSeconds,
    );
  }
}
