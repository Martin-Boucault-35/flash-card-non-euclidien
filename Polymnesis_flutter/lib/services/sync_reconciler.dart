import 'dart:math';

import '../models/card_model.dart';

/// Résultat d'une réconciliation local ⇄ Supabase.
class SyncResult {
  /// État final fusionné (deviendra la liste locale ET distante).
  final List<FlashCard> merged;

  /// Cartes à (ré)écrire sur Supabase (nouvelles ou modifiées).
  final List<FlashCard> toUpsert;

  /// Ids présents sur Supabase mais devenus des doublons → à supprimer.
  final List<String> remoteOrphanIds;

  const SyncResult({
    required this.merged,
    required this.toUpsert,
    required this.remoteOrphanIds,
  });
}

/// Union en préservant l'ordre, dédoublonnée de façon insensible à la casse.
List<String> _unionCaseInsensitive(Iterable<String> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final it in items) {
    final key = it.toLowerCase().trim();
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(it);
  }
  return out;
}

/// Fusionne un groupe de cartes partageant la même réponse en UNE carte.
FlashCard _mergeGroup(List<FlashCard> group) {
  if (group.length == 1) return group.first;

  // Carte "primaire" = la plus ancienne (id stable conservé).
  final primary =
      group.reduce((a, b) => a.createdAt <= b.createdAt ? a : b);
  // Carte "fraîche" = dernière modifiée (gagne pour les champs scalaires).
  final freshest =
      group.reduce((a, b) => a.updatedAt >= b.updatedAt ? a : b);

  return primary.copyWith(
    answer: freshest.answer,
    theme: freshest.theme,
    triggers: _unionCaseInsensitive(group.expand((c) => c.triggers)),
    acceptedAnswers: _unionCaseInsensitive(group.expand((c) => c.acceptedAnswers)),
    leitnerBox: freshest.leitnerBox,
    nextReviewAt: freshest.nextReviewAt,
    createdAt: group.map((c) => c.createdAt).reduce(min),
    updatedAt: group.map((c) => c.updatedAt).reduce(max),
  );
}

/// Réconcilie les cartes locales et distantes SANS perte ni doublon.
///
/// - Déduplique par **réponse normalisée** (identité réelle d'une carte).
/// - Fusionne triggers + réponses acceptées (union), garde la boîte Leitner de
///   la version la plus récente ([FlashCard.updatedAt]).
/// - Écarte les cartes de démo "pristines" (via [isPristineSeed]) quand le
///   distant a déjà du contenu, pour ne pas polluer le cloud.
SyncResult reconcileCards({
  required List<FlashCard> local,
  required List<FlashCard> remote,
  bool Function(FlashCard card)? isPristineSeed,
}) {
  // 1. Sur une install fraîche restaurée, ne pas pousser les cartes de démo.
  final localFiltered = (remote.isEmpty || isPristineSeed == null)
      ? local
      : local.where((c) => !isPristineSeed(c)).toList();

  // 2. Grouper le pool (local + distant) par réponse normalisée.
  final pool = [...localFiltered, ...remote];
  final groups = <String, List<FlashCard>>{};
  for (final c in pool) {
    var key = FlashCard.normalizeAnswer(c.answer);
    if (key.isEmpty) key = 'id:${c.id}'; // réponses vides : ne pas fusionner
    (groups[key] ??= []).add(c);
  }

  // 3. Fusionner chaque groupe.
  final merged = [for (final g in groups.values) _mergeGroup(g)];

  // 4. Déterminer ce qui doit être poussé / supprimé côté distant.
  final remoteById = {for (final c in remote) c.id: c};
  final keptIds = merged.map((c) => c.id).toSet();

  final toUpsert = merged.where((m) {
    final r = remoteById[m.id];
    return r == null ||
        r.updatedAt != m.updatedAt ||
        r.leitnerBox != m.leitnerBox ||
        r.nextReviewAt != m.nextReviewAt ||
        r.triggers.length != m.triggers.length ||
        r.acceptedAnswers.length != m.acceptedAnswers.length;
  }).toList();

  final remoteOrphanIds = remote
      .map((c) => c.id)
      .where((id) => !keptIds.contains(id))
      .toList();

  return SyncResult(
    merged: merged,
    toUpsert: toUpsert,
    remoteOrphanIds: remoteOrphanIds,
  );
}
