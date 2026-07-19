import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../constants.dart';

/// Résultat d'un import depuis "La Table des Savoirs".
class LtdsImportResult {
  final int cardsCreated;
  final int triggersAdded;
  final int acceptedAnswersAdded; // variantes ajoutées à des cartes existantes
  final int questionsFound;
  final int daysRequested;
  final List<int> daysWithData;
  final List<int> daysWithoutData; // jours demandés mais sans historique (404)
  final List<String> errors;

  LtdsImportResult({
    this.cardsCreated = 0,
    this.triggersAdded = 0,
    this.acceptedAnswersAdded = 0,
    this.questionsFound = 0,
    this.daysRequested = 0,
    this.daysWithData = const [],
    this.daysWithoutData = const [],
    this.errors = const [],
  });

  /// Message à afficher à l'utilisateur, le plus précis possible.
  String get summary {
    final buf = StringBuffer();
    if (questionsFound > 0) {
      buf.write('$cardsCreated carte(s) créée(s), '
          '$triggersAdded indice(s) ajouté(s).');
      if (acceptedAnswersAdded > 0) {
        buf.write(' $acceptedAnswersAdded variante(s) de réponse ajoutée(s).');
      }
    } else {
      buf.write('Aucune question importée.');
    }
    if (daysWithoutData.isNotEmpty) {
      buf.write(' Pas d\'historique pour le(s) jour(s) '
          '${daysWithoutData.join(', ')} — tu ne les as pas (encore) joués.');
    }
    if (errors.isNotEmpty) {
      buf.write(' ${errors.length} erreur(s) : ${errors.first}');
    }
    return buf.toString();
  }
}

/// Provider principal pour la gestion des cartes et de la synchronisation
class CardProvider extends ChangeNotifier {
  List<FlashCard> _cards = [];
  SyncCredentials _syncCredentials = SyncCredentials();
  LeitnerSettings _leitnerSettings = LeitnerSettings();
  LtdsSettings _ltdsSettings = LtdsSettings();
  bool _isSyncing = false;
  bool _syncError = false;
  bool _isInitialized = false;
  FlashCard? _editingCard;

  // Getters
  List<FlashCard> get cards => List.unmodifiable(_cards);
  SyncCredentials get syncCredentials => _syncCredentials;
  LeitnerSettings get leitnerSettings => _leitnerSettings;
  LtdsSettings get ltdsSettings => _ltdsSettings;
  bool get isSyncing => _isSyncing;
  bool get syncError => _syncError;
  bool get isInitialized => _isInitialized;
  FlashCard? get editingCard => _editingCard;
  int get cardCount => _cards.length;

  /// Initialise le provider avec les données stockées
  Future<void> initialize() async {
    await StorageService.initialize();

    // Charger les cartes
    _cards = StorageService.loadCards();
    if (_cards.isEmpty) {
      _cards = List.from(initialCards);
      await StorageService.saveCards(_cards);
    }

    // Charger les credentials de sync
    _syncCredentials = StorageService.loadSyncCredentials();

    // Charger les paramètres Leitner
    _leitnerSettings = StorageService.loadLeitnerSettings();

    // Charger les paramètres d'import "La Table des Savoirs"
    _ltdsSettings = StorageService.loadLtdsSettings();

    // Initialiser Supabase si configuré
    if (_syncCredentials.enabled && _syncCredentials.isConfigured) {
      await SupabaseService.reinitialize(_syncCredentials);
      await performSync();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Cartes de démo par défaut, indexées par id (pour la détection "pristine").
  static final Map<String, FlashCard> _seedById = {
    for (final c in initialCards) c.id: c,
  };

  /// Vrai si [c] est une carte de démo NON modifiée (à ne pas pousser au cloud).
  bool _isPristineSeed(FlashCard c) {
    final seed = _seedById[c.id];
    if (seed == null) return false;
    return seed.answer == c.answer && listEquals(seed.triggers, c.triggers);
  }

  /// Réconcilie local ⇄ Supabase, sans perte ni doublon (dédup par réponse).
  ///
  /// Tire les cartes distantes, fusionne avec le local (union des triggers /
  /// réponses acceptées, la plus récente gagne pour la boîte Leitner), pousse le
  /// résultat et supprime les doublons distants. Idempotent.
  Future<void> performSync() async {
    if (!_syncCredentials.enabled || !SupabaseService.isReady) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final remoteCards = await SupabaseService.fetchRemoteCards();
      if (remoteCards != null) {
        final result = reconcileCards(
          local: _cards,
          remote: remoteCards,
          isPristineSeed: _isPristineSeed,
        );
        _cards = result.merged;
        await StorageService.saveCards(_cards);

        if (result.toUpsert.isNotEmpty) {
          await SupabaseService.upsertCards(result.toUpsert);
        }
        if (result.remoteOrphanIds.isNotEmpty) {
          await SupabaseService.deleteCards(result.remoteOrphanIds);
        }
        _syncError = false;
      } else {
        _syncError = true; // fetch a échoué (Supabase injoignable/en pause ?)
      }
    } catch (e) {
      debugPrint('Sync error: $e');
      _syncError = true;
    }

    _isSyncing = false;
    notifyListeners();
  }

  /// Ajoute ou met à jour une carte
  Future<void> saveCard(FlashCard card) async {
    // Toute écriture utilisateur horodate la carte (arbitre de sync).
    final stamped =
        card.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch);
    final existingIndex = _cards.indexWhere((c) => c.id == stamped.id);

    if (existingIndex != -1) {
      _cards[existingIndex] = stamped;
    } else {
      _cards.insert(0, stamped);
    }

    await StorageService.saveCards(_cards);

    if (_syncCredentials.enabled) {
      _isSyncing = true;
      notifyListeners();
      await SupabaseService.upsertCard(stamped);
      _isSyncing = false;
    }

    notifyListeners();
  }

  /// Crée une nouvelle carte
  Future<void> addCard({
    required FlashCardTheme theme,
    required String answer,
    required List<String> triggers,
  }) async {
    final card = FlashCard(
      id: const Uuid().v4(),
      theme: theme,
      answer: answer.trim(),
      triggers: triggers.where((t) => t.trim().isNotEmpty).toList(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await saveCard(card);
  }

  /// Supprime une carte
  Future<void> deleteCard(String id) async {
    _cards.removeWhere((c) => c.id == id);
    await StorageService.saveCards(_cards);

    if (_syncCredentials.enabled) {
      _isSyncing = true;
      notifyListeners();
      await SupabaseService.deleteCard(id);
      _isSyncing = false;
    }

    notifyListeners();
  }

  /// Définit la carte en cours d'édition
  void setEditingCard(FlashCard? card) {
    _editingCard = card;
    notifyListeners();
  }

  /// Réinitialise l'état d'édition
  void resetEditingCard() {
    _editingCard = null;
    notifyListeners();
  }

  /// Met à jour les credentials de synchronisation
  Future<void> updateSyncCredentials(SyncCredentials creds) async {
    _syncCredentials = creds;
    await StorageService.saveSyncCredentials(creds);

    if (creds.enabled && creds.isConfigured) {
      await SupabaseService.reinitialize(creds);
      await performSync();
    }

    notifyListeners();
  }

  /// Filtre les cartes par thème, boîte Leitner et terme de recherche
  List<FlashCard> filterCards({String? searchTerm, FlashCardTheme? theme, int? leitnerBox}) {
    return _cards.where((card) {
      // Filtre par thème
      if (theme != null && card.theme != theme) {
        return false;
      }

      // Filtre par boîte Leitner
      if (leitnerBox != null && card.leitnerBox != leitnerBox) {
        return false;
      }

      // Filtre par recherche
      if (searchTerm != null && searchTerm.isNotEmpty) {
        final search = searchTerm.toLowerCase();
        final matchesAnswer = card.answer.toLowerCase().contains(search);
        final matchesTrigger = card.triggers.any(
          (t) => t.toLowerCase().contains(search),
        );
        return matchesAnswer || matchesTrigger;
      }

      return true;
    }).toList();
  }

  /// Récupère les cartes pour une partie selon la config
  List<FlashCard> getCardsForGame(List<String> themes, int count) {
    var pool = themes.isEmpty
        ? List<FlashCard>.from(_cards)
        : _cards.where((c) => themes.contains(c.theme.displayName)).toList();

    pool.shuffle();
    return pool.take(count).toList();
  }

  /// Compte le nombre de cartes disponibles selon les thèmes sélectionnés
  int getCardCountForThemes(List<String> themes) {
    if (themes.isEmpty) {
      return _cards.length;
    }
    return _cards.where((c) => themes.contains(c.theme.displayName)).length;
  }

  // ==================== Leitner System ====================

  /// Récupère les cartes à réviser aujourd'hui (nextReviewAt <= maintenant)
  List<FlashCard> getDailyCards() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _cards
        .where((c) => c.nextReviewAt <= now && c.leitnerBox <= _leitnerSettings.boxCount)
        .toList()
      ..shuffle();
  }

  /// Nombre de cartes à réviser aujourd'hui
  int get dailyCardCount => getDailyCards().length;

  /// Met à jour une carte après une bonne réponse
  /// [easy] = true si répondu en <10s → +2 boîtes, sinon +1
  Future<void> leitnerCorrect(FlashCard card, {bool easy = false}) async {
    final step = easy ? 2 : 1;
    final newBox = (card.leitnerBox + step).clamp(1, _leitnerSettings.boxCount + 1);
    final nextReview = newBox > _leitnerSettings.boxCount
        ? DateTime.now().add(const Duration(days: 365 * 10)).millisecondsSinceEpoch
        : _leitnerSettings.computeNextReview(newBox);

    final updated = card.copyWith(
      leitnerBox: newBox,
      nextReviewAt: nextReview,
    );
    await saveCard(updated);
  }

  /// Met à jour une carte après une mauvaise réponse (recule d'une boîte)
  Future<void> leitnerIncorrect(FlashCard card) async {
    final newBox = (card.leitnerBox - 1).clamp(1, _leitnerSettings.boxCount);
    final updated = card.copyWith(
      leitnerBox: newBox,
      nextReviewAt: _leitnerSettings.computeNextReview(newBox),
    );
    await saveCard(updated);
  }

  /// Met à jour les paramètres Leitner
  Future<void> updateLeitnerSettings(LeitnerSettings settings) async {
    _leitnerSettings = settings;
    await StorageService.saveLeitnerSettings(settings);
    notifyListeners();
  }

  // ==================== Import La Table des Savoirs ====================

  /// Met à jour les paramètres d'import (jeton).
  Future<void> updateLtdsSettings(LtdsSettings settings) async {
    _ltdsSettings = settings;
    await StorageService.saveLtdsSettings(settings);
    notifyListeners();
  }

  /// Importe les cartes des quiz "La Table des Savoirs" pour les [days] donnés.
  ///
  /// Récupère les deux niveaux (abordable + expert). Chaque question devient une
  /// carte (réponse = réponse attendue, indice = énoncé). Si une carte avec la
  /// même réponse existe déjà, l'énoncé est ajouté comme indice supplémentaire —
  /// l'import est donc idempotent (rejouer un jour ne crée pas de doublons).
  ///
  /// [client] permet d'injecter un faux client HTTP dans les tests.
  /// Lève [LtdsAuthException] si le jeton est absent, invalide ou expiré.
  Future<LtdsImportResult> importFromLtds({
    required List<int> days,
    http.Client? client,
  }) async {
    final token = _ltdsSettings.token.trim();
    if (token.isEmpty) {
      throw LtdsAuthException('Aucun jeton configuré.');
    }

    var cardsCreated = 0;
    var triggersAdded = 0;
    var acceptedAnswersAdded = 0;
    var questionsFound = 0;
    final daysWithData = <int>{};
    final errors = <String>[];
    final changed = <String, FlashCard>{}; // id -> dernière version à syncer

    for (final day in days) {
      for (final level in LtdsImportService.levels.keys) {
        List<LtdsQuestion> questions;
        try {
          questions = await LtdsImportService.fetchDay(
            token: token,
            day: day,
            level: level,
            client: client,
          );
        } on LtdsAuthException {
          rethrow; // problème de jeton : on arrête tout
        } catch (e) {
          errors.add('Jour $day ($level) : $e');
          continue;
        }

        if (questions.isNotEmpty) daysWithData.add(day);

        for (final q in questions) {
          questionsFound++;
          final normAnswer = q.answer.toLowerCase().trim();
          final idx = _cards.indexWhere(
            (c) => c.answer.toLowerCase().trim() == normAnswer,
          );

          if (idx == -1) {
            final card = FlashCard(
              id: const Uuid().v4(),
              theme: q.theme,
              answer: q.answer,
              triggers: [q.question],
              createdAt: DateTime.now().millisecondsSinceEpoch,
              acceptedAnswers: q.validAnswers,
            );
            _cards.insert(0, card);
            changed[card.id] = card;
            cardsCreated++;
          } else {
            final existing = _cards[idx];
            final normQuestion = q.question.toLowerCase().trim();
            final hasTrigger = existing.triggers.any(
              (t) => t.toLowerCase().trim() == normQuestion,
            );

            // Fusionne les nouvelles réponses acceptées (dédup insensible à la casse).
            final existingAccepted =
                existing.acceptedAnswers.map((a) => a.toLowerCase().trim()).toSet();
            final newAccepted = q.validAnswers
                .where((a) => !existingAccepted.contains(a.toLowerCase().trim()))
                .toList();

            if (!hasTrigger || newAccepted.isNotEmpty) {
              final updated = existing.copyWith(
                triggers: hasTrigger
                    ? existing.triggers
                    : [...existing.triggers, q.question],
                acceptedAnswers: [...existing.acceptedAnswers, ...newAccepted],
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              );
              _cards[idx] = updated;
              changed[updated.id] = updated;
              if (!hasTrigger) triggersAdded++;
              acceptedAnswersAdded += newAccepted.length;
            }
          }
        }
      }
    }

    if (changed.isNotEmpty) {
      await StorageService.saveCards(_cards);
      if (_syncCredentials.enabled) {
        _isSyncing = true;
        notifyListeners();
        for (final card in changed.values) {
          await SupabaseService.upsertCard(card);
        }
        _isSyncing = false;
      }
    }

    notifyListeners();

    final withoutData = days.where((d) => !daysWithData.contains(d)).toList()
      ..sort();

    return LtdsImportResult(
      cardsCreated: cardsCreated,
      triggersAdded: triggersAdded,
      acceptedAnswersAdded: acceptedAnswersAdded,
      questionsFound: questionsFound,
      daysRequested: days.length,
      daysWithData: daysWithData.toList()..sort(),
      daysWithoutData: withoutData,
      errors: errors,
    );
  }

  /// Appelé quand le jeu quotidien est terminé — annule les notifs du jour
  Future<void> markDailyCompleted() async {
    await NotificationService.cancelTodayReminder();
  }
}
