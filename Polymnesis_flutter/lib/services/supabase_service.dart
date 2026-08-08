import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Service de synchronisation Supabase
class SupabaseService {
  static SupabaseClient? _client;
  static bool _isInitialized = false;

  // Credentials du client courant, pour détecter un vrai changement de projet
  // dans [reinitialize] (et non re-créer un client à l'identique).
  static String _currentUrl = '';
  static String _currentKey = '';

  /// Initialise le client Supabase avec les credentials fournis
  static Future<bool> initialize(SyncCredentials creds) async {
    if (!creds.enabled || !creds.isConfigured) {
      _client = null;
      _isInitialized = false;
      return false;
    }

    try {
      await Supabase.initialize(
        url: creds.url,
        anonKey: creds.key,
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
      _currentUrl = creds.url;
      _currentKey = creds.key;
      return true;
    } catch (e) {
      print('Failed to init Supabase: $e');
      _client = null;
      _isInitialized = false;
      return false;
    }
  }

  /// Réinitialise le client avec de nouveaux credentials.
  ///
  /// Si un client existe déjà pour les MÊMES url/clé, on ne fait rien. S'ils
  /// ont changé (restauration d'un autre « compte » en cours de session), on
  /// jette l'instance et on en recrée une — sinon la sync continuerait en
  /// silence contre l'ancien projet.
  static Future<bool> reinitialize(SyncCredentials creds) async {
    if (!creds.enabled || !creds.isConfigured) {
      _client = null;
      _isInitialized = false;
      return false;
    }

    try {
      if (_isInitialized && _client != null) {
        if (creds.url == _currentUrl && creds.key == _currentKey) {
          return true; // mêmes credentials : rien à faire
        }
        // Changement de projet : il faut détruire l'instance globale d'abord
        // (Supabase.initialize refuse une double initialisation).
        _client = null;
        _isInitialized = false;
        await Supabase.instance.dispose();
      }

      await Supabase.initialize(
        url: creds.url,
        anonKey: creds.key,
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
      _currentUrl = creds.url;
      _currentKey = creds.key;
      return true;
    } catch (e) {
      // Échec (ex. dispose impossible sur cette plateforme) : état "non prêt",
      // le bandeau d'erreur sync existant s'affichera ; un redémarrage suffit.
      print('Failed to reinit Supabase: $e');
      _client = null;
      _isInitialized = false;
      return false;
    }
  }

  /// Vérifie si le service est prêt
  static bool get isReady => _isInitialized && _client != null;

  /// Récupère toutes les cartes depuis Supabase
  static Future<List<FlashCard>?> fetchRemoteCards() async {
    if (!isReady) return null;

    try {
      final response = await _client!.from('cards').select();

      return (response as List).map((row) {
        return FlashCard.fromJson(row as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Error fetching cards: $e');
      return null;
    }
  }

  /// Sauvegarde ou met à jour une carte sur Supabase
  static Future<bool> upsertCard(FlashCard card) async {
    if (!isReady) return false;

    try {
      await _client!.from('cards').upsert({
        'id': card.id,
        'data': card.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error saving card: $e');
      return false;
    }
  }

  /// Supprime une carte de Supabase
  static Future<bool> deleteCard(String id) async {
    if (!isReady) return false;

    try {
      await _client!.from('cards').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error deleting card: $e');
      return false;
    }
  }

  /// Upsert en lot (une seule requête) pour la réconciliation de sync.
  static Future<bool> upsertCards(List<FlashCard> cards) async {
    if (!isReady || cards.isEmpty) return false;

    try {
      final now = DateTime.now().toIso8601String();
      await _client!.from('cards').upsert(
            cards
                .map((c) => {'id': c.id, 'data': c.toJson(), 'updated_at': now})
                .toList(),
          );
      return true;
    } catch (e) {
      print('Error bulk upserting cards: $e');
      return false;
    }
  }

  /// Supprime en lot les cartes dont l'id est dans [ids] (doublons distants).
  static Future<bool> deleteCards(List<String> ids) async {
    if (!isReady || ids.isEmpty) return false;

    try {
      await _client!.from('cards').delete().inFilter('id', ids);
      return true;
    } catch (e) {
      print('Error bulk deleting cards: $e');
      return false;
    }
  }

  /// Id de la ligne de réglages. 'default' tant que l'app est mono-utilisateur ;
  /// deviendra un user_id avec les vrais comptes (option A).
  static const String settingsRowId = 'default';

  /// Récupère les réglages synchronisés. `null` si la ligne n'existe pas
  /// encore, si la table est absente, ou en cas d'erreur réseau.
  static Future<SyncedSettings?> fetchUserSettings() async {
    if (!isReady) return null;

    try {
      final row = await _client!
          .from('user_settings')
          .select('data')
          .eq('id', settingsRowId)
          .maybeSingle();
      final data = row?['data'];
      if (data is! Map<String, dynamic>) return null;
      return SyncedSettings.fromJson(data);
    } catch (e) {
      print('Error fetching user settings: $e');
      return null;
    }
  }

  /// Pousse les réglages synchronisés (upsert de la ligne unique).
  static Future<bool> upsertUserSettings(SyncedSettings settings) async {
    if (!isReady) return false;

    try {
      await _client!.from('user_settings').upsert({
        'id': settingsRowId,
        'data': settings.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error upserting user settings: $e');
      return false;
    }
  }

  /// Lit l'archive `ltds_questions` et renvoie les réponses par jour.
  ///
  /// Ne récupère que les colonnes `day` et `answer` (léger), et **pagine** :
  /// l'archive dépasse la limite par défaut de 1000 lignes de PostgREST.
  /// Renvoie `null` si Supabase n'est pas prêt ou en cas d'erreur.
  static Future<Map<int, List<String>>?> fetchArchiveAnswersByDay() async {
    if (!isReady) return null;

    try {
      final byDay = <int, List<String>>{};
      const pageSize = 1000;
      var from = 0;

      while (true) {
        final rows = await _client!
            .from('ltds_questions')
            .select('day, answer')
            .range(from, from + pageSize - 1) as List;

        for (final row in rows) {
          final m = row as Map<String, dynamic>;
          final day = m['day'] as int?;
          final answer = m['answer'] as String?;
          if (day == null || answer == null) continue;
          (byDay[day] ??= []).add(answer);
        }

        if (rows.length < pageSize) break; // dernière page
        from += pageSize;
      }
      return byDay;
    } catch (e) {
      print('Error fetching ltds_questions archive: $e');
      return null;
    }
  }
}
