import '../models/card_model.dart';
import '../models/day_import_status.dart';

/// Calcule l'état d'import de chaque jour LTDS en comparant l'archive Supabase
/// aux cartes présentes localement. **Fonction pure** (aucune I/O) : tout ce
/// qui touche au réseau/stockage est fait par l'appelant.
///
/// - [archiveAnswersByDay] : réponses connues par jour (colonne `answer` de
///   `ltds_questions`, un jour = ses questions abordables + expertes).
/// - [localNormalizedAnswers] : toutes les réponses locales déjà normalisées
///   (union de `FlashCard.allAcceptedNormalized`).
///
/// Le tableau couvre les jours `1..maxJourArchivé`. Un jour **absent** de
/// l'archive dans cette plage est un « trou » = non joué. On ne va pas au-delà
/// du dernier jour archivé : les jours futurs n'existent pas encore côté joueur.
List<DayImportStatus> computeDayStatuses({
  required Map<int, List<String>> archiveAnswersByDay,
  required Set<String> localNormalizedAnswers,
}) {
  if (archiveAnswersByDay.isEmpty) return const [];

  final maxDay = archiveAnswersByDay.keys.reduce((a, b) => a > b ? a : b);
  final result = <DayImportStatus>[];

  for (var day = 1; day <= maxDay; day++) {
    final answers = archiveAnswersByDay[day];
    if (answers == null || answers.isEmpty) {
      result.add(DayImportStatus(day: day, present: 0, total: 0)); // non joué
      continue;
    }

    // Dédoublonnage sur la réponse normalisée : deux questions à réponse
    // identique ne comptent pas double, et on compare dans le même espace que
    // les réponses locales.
    final normalized = <String>{};
    for (final a in answers) {
      final n = FlashCard.normalizeAnswer(a);
      if (n.isNotEmpty) normalized.add(n);
    }
    final present =
        normalized.where(localNormalizedAnswers.contains).length;

    result.add(
      DayImportStatus(day: day, present: present, total: normalized.length),
    );
  }

  return result;
}
