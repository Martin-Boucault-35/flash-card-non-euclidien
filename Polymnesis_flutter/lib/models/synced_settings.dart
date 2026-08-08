import 'leitner_settings.dart';
import 'ltds_settings.dart';

/// Enveloppe des réglages synchronisés avec Supabase (table `user_settings`) :
/// réglages Leitner + jeton LTDS, chacun avec SA date de dernière modification.
///
/// Les timestamps sont PAR SECTION, pas globaux : changer le jeton sur un
/// appareil ne doit pas écraser un réglage Leitner plus récent fait sur un
/// autre. Chaque section suit sa propre horloge (« le plus récent gagne »).
class SyncedSettings {
  final LeitnerSettings leitner;
  final int leitnerUpdatedAt; // ms epoch, 0 = jamais modifié
  final LtdsSettings ltds;
  final int ltdsUpdatedAt;

  const SyncedSettings({
    required this.leitner,
    this.leitnerUpdatedAt = 0,
    required this.ltds,
    this.ltdsUpdatedAt = 0,
  });

  factory SyncedSettings.fromJson(Map<String, dynamic> json) {
    return SyncedSettings(
      leitner: json['leitner'] is Map<String, dynamic>
          ? LeitnerSettings.fromJson(json['leitner'] as Map<String, dynamic>)
          : LeitnerSettings(),
      leitnerUpdatedAt: json['leitnerAt'] as int? ?? 0,
      ltds: json['ltds'] is Map<String, dynamic>
          ? LtdsSettings.fromJson(json['ltds'] as Map<String, dynamic>)
          : LtdsSettings(),
      ltdsUpdatedAt: json['ltdsAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'leitner': leitner.toJson(),
        'leitnerAt': leitnerUpdatedAt,
        'ltds': ltds.toJson(),
        'ltdsAt': ltdsUpdatedAt,
      };

  /// Fusionne avec [remote] : chaque section garde la version la plus récente.
  /// À timestamps égaux, le local gagne (pas d'écriture inutile).
  SyncedSettings merge(SyncedSettings remote) {
    final remoteLeitnerWins = remote.leitnerUpdatedAt > leitnerUpdatedAt;
    final remoteLtdsWins = remote.ltdsUpdatedAt > ltdsUpdatedAt;
    return SyncedSettings(
      leitner: remoteLeitnerWins ? remote.leitner : leitner,
      leitnerUpdatedAt:
          remoteLeitnerWins ? remote.leitnerUpdatedAt : leitnerUpdatedAt,
      ltds: remoteLtdsWins ? remote.ltds : ltds,
      ltdsUpdatedAt: remoteLtdsWins ? remote.ltdsUpdatedAt : ltdsUpdatedAt,
    );
  }

  /// Vrai si au moins une section locale est plus récente que [remote]
  /// (⇒ il faut pousser le résultat du merge).
  bool newerThan(SyncedSettings remote) =>
      leitnerUpdatedAt > remote.leitnerUpdatedAt ||
      ltdsUpdatedAt > remote.ltdsUpdatedAt;
}
