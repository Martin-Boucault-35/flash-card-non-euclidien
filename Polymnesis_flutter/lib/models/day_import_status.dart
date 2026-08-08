/// État d'import d'un jour LTDS, calculé en comparant l'archive Supabase
/// (`ltds_questions`) aux cartes présentes localement.
enum DayImportState {
  /// Toutes les questions du jour sont dans la collection.
  fullyImported,

  /// Une partie seulement (carte supprimée, import avant les variantes…).
  partial,

  /// Jour joué (présent dans l'archive) mais aucune question importée.
  notImported,

  /// Jour absent de l'archive : pas joué (ou pas encore archivé).
  notPlayed,
}

/// Statut d'un jour : combien de ses questions sont déjà chez nous.
class DayImportStatus {
  final int day;
  final int present; // questions du jour présentes localement
  final int total; // questions connues pour ce jour (0 si non joué)

  const DayImportStatus({
    required this.day,
    required this.present,
    required this.total,
  });

  DayImportState get state {
    if (total == 0) return DayImportState.notPlayed;
    if (present >= total) return DayImportState.fullyImported;
    if (present == 0) return DayImportState.notImported;
    return DayImportState.partial;
  }

  Map<String, dynamic> toJson() => {'d': day, 'p': present, 't': total};

  factory DayImportStatus.fromJson(Map<String, dynamic> json) => DayImportStatus(
        day: json['d'] as int? ?? 0,
        present: json['p'] as int? ?? 0,
        total: json['t'] as int? ?? 0,
      );
}
