/// Configuration des intervalles Leitner (en jours)
class LeitnerSettings {
  /// Intervalles par défaut: 1j, 3j, 7j, 14j, 30j, 90j
  static const List<int> defaultIntervals = [1, 3, 7, 14, 30, 90];

  final List<int> intervals;

  LeitnerSettings({List<int>? intervals})
      : intervals = intervals ?? List.from(defaultIntervals);

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

  LeitnerSettings copyWith({List<int>? intervals}) {
    return LeitnerSettings(intervals: intervals ?? List.from(this.intervals));
  }

  Map<String, dynamic> toJson() => {'intervals': intervals};

  factory LeitnerSettings.fromJson(Map<String, dynamic> json) {
    return LeitnerSettings(
      intervals: (json['intervals'] as List?)?.cast<int>() ??
          List.from(defaultIntervals),
    );
  }
}
