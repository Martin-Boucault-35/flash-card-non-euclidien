import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../constants.dart';

/// Une question réellement importée (carte créée ou indice ajouté), pour
/// pouvoir afficher le détail des questions importées à l'utilisateur.
/// Nature d'une question rencontrée pendant l'import.
enum ImportKind {
  created, // nouvelle carte créée
  triggerAdded, // indice ajouté à une carte existante
  alreadyPresent, // question déjà présente (rien de nouveau)
}

class ImportedQuestion {
  final String answer;
  final String question;
  final ImportKind kind;

  const ImportedQuestion({
    required this.answer,
    required this.question,
    required this.kind,
  });
}

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

  /// Détail des questions importées (carte créée ou indice ajouté).
  final List<ImportedQuestion> imported;

  LtdsImportResult({
    this.cardsCreated = 0,
    this.triggersAdded = 0,
    this.acceptedAnswersAdded = 0,
    this.questionsFound = 0,
    this.daysRequested = 0,
    this.daysWithData = const [],
    this.daysWithoutData = const [],
    this.errors = const [],
    this.imported = const [],
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

  // Tableau "jours importés" (issue #7) — calculé depuis l'archive Supabase.
  List<DayImportStatus> _importedDays = const [];
  int? _importedDaysAt; // date du dernier calcul (ms epoch)
  bool _loadingImportedDays = false;

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
  List<DayImportStatus> get importedDays => List.unmodifiable(_importedDays);
  bool get loadingImportedDays => _loadingImportedDays;
  DateTime? get importedDaysComputedAt => _importedDaysAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(_importedDaysAt!);

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

    // Charger le tableau "jours importés" mis en cache (issue #7)
    final (days, at) = StorageService.loadImportedDays();
    _importedDays = days;
    _importedDaysAt = at;

    // Initialiser Supabase si configuré
    if (_syncCredentials.enabled && _syncCredentials.isConfigured) {
      await SupabaseService.reinitialize(_syncCredentials);
      await performSync();
    }

    // Reconstituer l'événement d'origine des cartes antérieures à l'historique
    // (après la sync, pour tenir compte des cartes redescendues du cloud).
    await backfillOrigins();

    _isInitialized = true;
    notifyListeners();
  }

  /// Donne à chaque carte un premier événement daté de son [FlashCard.createdAt]
  /// réel, pour les cartes créées avant l'arrivée de l'historique.
  ///
  /// - `acceptedAnswers` non vide ⇒ `imported` (seul l'import LTDS remplit ce
  ///   champ, donc l'origine est certaine) ;
  /// - sinon ⇒ `added`, libellé neutre : des cartes ont été importées AVANT
  ///   l'arrivée des réponses acceptées, les dire « créées à la main » serait faux.
  ///
  /// Si une carte marquée `added` gagne plus tard des réponses acceptées (via un
  /// ré-import), son événement d'origine est **promu** en `imported` sans perdre
  /// sa date. Seul cet événement synthétique est modifiable : le véritable
  /// historique de révisions n'est jamais retouché. Idempotent.
  Future<void> backfillOrigins() async {
    final changed = <FlashCard>[];

    for (var i = 0; i < _cards.length; i++) {
      final card = _cards[i];
      final isImported = card.acceptedAnswers.isNotEmpty;

      if (card.history.isEmpty) {
        _cards[i] = card.copyWith(history: [
          CardEvent(
            type: isImported ? CardEventType.imported : CardEventType.added,
            fromBox: 1,
            toBox: 1,
            at: card.createdAt,
          ),
        ]);
        changed.add(_cards[i]);
        continue;
      }

      // Promotion `added` -> `imported` quand les variantes arrivent après coup.
      final first = card.history.first;
      if (first.type == CardEventType.added && isImported) {
        final promoted = [
          CardEvent(
            type: CardEventType.imported,
            fromBox: first.fromBox,
            toBox: first.toBox,
            at: first.at, // on conserve la vraie date
          ),
          ...card.history.skip(1),
        ];
        _cards[i] = card.copyWith(history: promoted);
        changed.add(_cards[i]);
      }
    }

    if (changed.isEmpty) return; // rien à faire : aucune écriture inutile

    await StorageService.saveCards(_cards);
    if (_syncCredentials.enabled && SupabaseService.isReady) {
      await SupabaseService.upsertCards(changed);
    }
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
    final now = DateTime.now().millisecondsSinceEpoch;
    final card = FlashCard(
      id: const Uuid().v4(),
      theme: theme,
      answer: answer.trim(),
      triggers: triggers.where((t) => t.trim().isNotEmpty).toList(),
      createdAt: now,
      history: [
        CardEvent(type: CardEventType.created, fromBox: 1, toBox: 1, at: now),
      ],
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

  /// Version À JOUR de [card] depuis l'état du provider. Le daily game peut
  /// repasser une carte déjà mutée dans la même session (ré-insertion après
  /// échec) avec un snapshot périmé : muter ce snapshot écraserait la boîte ET
  /// l'historique déjà enregistrés. On repart donc toujours de la carte vivante.
  FlashCard _liveCard(FlashCard card) =>
      _cards.firstWhere((c) => c.id == card.id, orElse: () => card);

  /// Met à jour une carte après une bonne réponse
  /// [easy] = true si répondu en <10s → +2 boîtes, sinon +1
  Future<void> leitnerCorrect(FlashCard card, {bool easy = false}) async {
    final live = _liveCard(card);
    final step = easy ? 2 : 1;
    final newBox = (live.leitnerBox + step).clamp(1, _leitnerSettings.boxCount + 1);
    final nextReview = newBox > _leitnerSettings.boxCount
        ? DateTime.now().add(const Duration(days: 365 * 10)).millisecondsSinceEpoch
        : _leitnerSettings.computeNextReview(newBox);

    final updated = live.copyWith(
      leitnerBox: newBox,
      nextReviewAt: nextReview,
      history: [
        ...live.history,
        CardEvent(
          type: easy ? CardEventType.correctFast : CardEventType.correct,
          fromBox: live.leitnerBox,
          toBox: newBox,
          at: DateTime.now().millisecondsSinceEpoch,
        ),
      ],
    );
    await saveCard(updated);
  }

  /// Met à jour une carte après une mauvaise réponse (recule d'une boîte).
  /// [skipped] = true si la question a été passée (plutôt que mal répondue).
  Future<void> leitnerIncorrect(FlashCard card, {bool skipped = false}) async {
    final live = _liveCard(card);
    final newBox = (live.leitnerBox - 1).clamp(1, _leitnerSettings.boxCount);
    final updated = live.copyWith(
      leitnerBox: newBox,
      nextReviewAt: _leitnerSettings.computeNextReview(newBox),
      history: [
        ...live.history,
        CardEvent(
          type: skipped ? CardEventType.skipped : CardEventType.wrong,
          fromBox: live.leitnerBox,
          toBox: newBox,
          at: DateTime.now().millisecondsSinceEpoch,
        ),
      ],
    );
    await saveCard(updated);
  }

  /// Met à jour les paramètres Leitner
  Future<void> updateLeitnerSettings(LeitnerSettings settings) async {
    final oldCount = _leitnerSettings.boxCount;
    final newCount = settings.boxCount;

    _leitnerSettings = settings;
    await StorageService.saveLeitnerSettings(settings);

    if (newCount != oldCount) {
      await _remapCardsToBoxes(oldCount: oldCount, newCount: newCount);
    }

    notifyListeners();
  }

  /// Replace les cartes quand le nombre de boîtes change.
  ///
  /// - Une carte **maîtrisée** le reste (elle était au-delà de l'ancienne
  ///   dernière boîte, elle passe au-delà de la nouvelle) : on ne remet jamais
  ///   en révision une carte déjà acquise.
  /// - Une carte dont la boîte **disparaît** atterrit sur la dernière boîte
  ///   avant « Maîtrisé » (ex. boîte 6 alors qu'il n'en reste que 5 -> boîte 5).
  /// - Les autres ne bougent pas.
  ///
  /// Le déplacement est tracé dans l'historique pour que le graphe reste
  /// cohérent (sinon la boîte courante ne correspondrait plus au dernier
  /// événement). La date de prochaine révision est recalculée sur la nouvelle
  /// boîte, sauf pour les cartes maîtrisées qui gardent leur échéance lointaine.
  Future<void> _remapCardsToBoxes({
    required int oldCount,
    required int newCount,
  }) async {
    final changed = <FlashCard>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < _cards.length; i++) {
      final card = _cards[i];
      final wasMastered = card.leitnerBox > oldCount;

      final int target;
      if (wasMastered) {
        target = newCount + 1; // reste maîtrisée
      } else if (card.leitnerBox > newCount) {
        target = newCount; // sa boîte n'existe plus
      } else {
        continue; // rien à faire
      }
      if (target == card.leitnerBox) continue;

      final updated = card.copyWith(
        leitnerBox: target,
        nextReviewAt: target > newCount
            ? card.nextReviewAt // maîtrisée : on garde l'échéance lointaine
            : _leitnerSettings.computeNextReview(target),
        updatedAt: now,
        history: [
          ...card.history,
          CardEvent(
            type: CardEventType.boxesResized,
            fromBox: card.leitnerBox,
            toBox: target,
            at: now,
          ),
        ],
      );
      _cards[i] = updated;
      changed.add(updated);
    }

    if (changed.isEmpty) return;

    await StorageService.saveCards(_cards);
    if (_syncCredentials.enabled && SupabaseService.isReady) {
      await SupabaseService.upsertCards(changed);
    }
  }

  // ==================== Import La Table des Savoirs ====================

  /// Met à jour les paramètres d'import (jeton).
  Future<void> updateLtdsSettings(LtdsSettings settings) async {
    _ltdsSettings = settings;
    await StorageService.saveLtdsSettings(settings);
    notifyListeners();
  }

  /// (Re)calcule le tableau « jours importés » à partir de l'archive Supabase
  /// et des cartes locales, puis le met en cache. Nécessite la sync active
  /// (l'archive vit dans Supabase) ; ne touche PAS à l'API LTDS.
  Future<void> refreshImportedDays() async {
    if (!_syncCredentials.enabled || !SupabaseService.isReady) return;

    _loadingImportedDays = true;
    notifyListeners();
    try {
      final archive = await SupabaseService.fetchArchiveAnswersByDay();
      if (archive == null) return; // erreur réseau : on garde le cache existant

      final local = <String>{
        for (final c in _cards) ...c.allAcceptedNormalized,
      };
      _importedDays = computeDayStatuses(
        archiveAnswersByDay: archive,
        localNormalizedAnswers: local,
      );
      _importedDaysAt = DateTime.now().millisecondsSinceEpoch;
      await StorageService.saveImportedDays(_importedDays, _importedDaysAt!);
    } finally {
      _loadingImportedDays = false;
      notifyListeners();
    }
  }

  /// Importe le **dernier jour** = jour courant − 1. On vise la veille plutôt
  /// que le jour même pour un résultat déterministe (le quiz d'hier est terminé
  /// et joué, alors que celui du jour peut être « trop tôt »). Récupère le jour
  /// courant via `/info` puis réutilise [importFromLtds].
  Future<LtdsImportResult> importLastDay({http.Client? client}) async {
    final day = await LtdsImportService.getCurrentDay(client: client) - 1;
    return importFromLtds(days: [day], client: client);
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
    final imported = <ImportedQuestion>[]; // questions réellement importées
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
            final now = DateTime.now().millisecondsSinceEpoch;
            final card = FlashCard(
              id: const Uuid().v4(),
              theme: q.theme,
              answer: q.answer,
              triggers: [q.question],
              createdAt: now,
              acceptedAnswers: q.validAnswers,
              history: [
                CardEvent(
                    type: CardEventType.imported, fromBox: 1, toBox: 1, at: now),
              ],
            );
            _cards.insert(0, card);
            changed[card.id] = card;
            cardsCreated++;
            imported.add(ImportedQuestion(
                answer: q.answer,
                question: q.question,
                kind: ImportKind.created));
          } else {
            final existing = _cards[idx];
            final normQuestion = q.question.toLowerCase().trim();
            final hasTrigger = existing.triggers.any(
              (t) => t.toLowerCase().trim() == normQuestion,
            );

            // Question déjà connue -> "déjà présente" ; sinon "indice ajouté".
            imported.add(ImportedQuestion(
              answer: q.answer,
              question: q.question,
              kind: hasTrigger
                  ? ImportKind.alreadyPresent
                  : ImportKind.triggerAdded,
            ));

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
      imported: imported,
    );
  }

  /// Appelé quand le jeu quotidien est terminé — annule les notifs du jour
  Future<void> markDailyCompleted() async {
    await NotificationService.cancelTodayReminder();
  }
}
