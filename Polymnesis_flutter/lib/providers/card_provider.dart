import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../constants.dart';

/// Provider principal pour la gestion des cartes et de la synchronisation
class CardProvider extends ChangeNotifier {
  List<FlashCard> _cards = [];
  SyncCredentials _syncCredentials = SyncCredentials();
  bool _isSyncing = false;
  bool _isInitialized = false;
  FlashCard? _editingCard;

  // Getters
  List<FlashCard> get cards => List.unmodifiable(_cards);
  SyncCredentials get syncCredentials => _syncCredentials;
  bool get isSyncing => _isSyncing;
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

    // Initialiser Supabase si configuré
    if (_syncCredentials.enabled && _syncCredentials.isConfigured) {
      await SupabaseService.reinitialize(_syncCredentials);
      await performSync();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Effectue une synchronisation avec Supabase
  Future<void> performSync() async {
    if (!_syncCredentials.enabled || !SupabaseService.isReady) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final remoteCards = await SupabaseService.fetchRemoteCards();
      if (remoteCards != null) {
        // Stratégie simple: merge remote into local, prefer remote if duplicates
        final remoteIds = remoteCards.map((c) => c.id).toSet();
        final localOnly = _cards.where((c) => !remoteIds.contains(c.id)).toList();
        _cards = [...remoteCards, ...localOnly];
        await StorageService.saveCards(_cards);
      }
    } catch (e) {
      debugPrint('Sync error: $e');
    }

    _isSyncing = false;
    notifyListeners();
  }

  /// Ajoute ou met à jour une carte
  Future<void> saveCard(FlashCard card) async {
    final existingIndex = _cards.indexWhere((c) => c.id == card.id);

    if (existingIndex != -1) {
      _cards[existingIndex] = card;
    } else {
      _cards.insert(0, card);
    }

    await StorageService.saveCards(_cards);

    if (_syncCredentials.enabled) {
      _isSyncing = true;
      notifyListeners();
      await SupabaseService.upsertCard(card);
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

  /// Filtre les cartes par thème et terme de recherche
  List<FlashCard> filterCards({String? searchTerm, FlashCardTheme? theme}) {
    return _cards.where((card) {
      // Filtre par thème
      if (theme != null && card.theme != theme) {
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
}
