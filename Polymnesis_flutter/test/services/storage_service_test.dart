import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:polymnesis/models/models.dart';
import 'package:polymnesis/services/storage_service.dart';

import '../helpers/test_helpers.dart';

/// Couverture de [StorageService] (API statique adossée à SharedPreferences) :
///   - saveCards/loadCards : round-trip d'une liste de FlashCard (id, answer,
///     leitnerBox, nextReviewAt, theme, triggers, createdAt préservés).
///   - loadCards sur prefs vides (aucune clé) renvoie [].
///   - loadCards sur JSON corrompu renvoie [] sans lever d'exception.
///   - saveSyncCredentials/loadSyncCredentials : round-trip + défaut quand absent.
///   - saveLeitnerSettings/loadLeitnerSettings : round-trip + défaut quand absent
///     + JSON corrompu => valeurs par défaut.
///   - Les clés réellement stockées sont bien
///     'polymnesis-cards' / 'polymnesis-sync-creds' / 'polymnesis-leitner-settings'.
///
/// [StorageService] mémorise un `_prefs` statique : `initialize()` doit donc être
/// rappelé après chaque `setMockInitialValues` (fait dans le setUp).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.initialize();
  });

  group('StorageService - cartes', () {
    test('saveCards puis loadCards effectue un round-trip complet', () async {
      final cards = [
        buildCard(
          id: 'c1',
          theme: FlashCardTheme.histoire,
          answer: 'Napoléon',
          triggers: const ['empereur', 'Corse'],
          createdAt: 1234,
          leitnerBox: 3,
          nextReviewAt: 5678,
        ),
        buildCard(
          id: 'c2',
          theme: FlashCardTheme.geographie,
          answer: 'Stromboli',
          triggers: const ['volcan'],
          createdAt: 999,
          leitnerBox: 1,
          nextReviewAt: 999,
        ),
      ];

      await StorageService.saveCards(cards);
      final loaded = StorageService.loadCards();

      expect(loaded.length, 2);

      final first = loaded.firstWhere((c) => c.id == 'c1');
      expect(first.theme, FlashCardTheme.histoire);
      expect(first.answer, 'Napoléon');
      expect(first.triggers, const ['empereur', 'Corse']);
      expect(first.createdAt, 1234);
      expect(first.leitnerBox, 3);
      expect(first.nextReviewAt, 5678);

      final second = loaded.firstWhere((c) => c.id == 'c2');
      expect(second.theme, FlashCardTheme.geographie);
      expect(second.answer, 'Stromboli');
      expect(second.leitnerBox, 1);
      expect(second.nextReviewAt, 999);
    });

    test('loadCards renvoie [] quand aucune carte n\'est stockée', () {
      // setUp a posé des prefs vides : aucune clé 'polymnesis-cards'.
      expect(StorageService.loadCards(), isEmpty);
    });

    test('loadCards renvoie [] sur du JSON corrompu sans lever', () async {
      SharedPreferences.setMockInitialValues({kCardsKey: 'not json{'});
      await StorageService.initialize();

      // silencePrints : le catch de StorageService journalise via print() — c'est
      // un chemin attendu, on évite juste de polluer la sortie des tests.
      expect(silencePrints(() => StorageService.loadCards()), isEmpty);
    });

    test('saveCards écrit bien sous la clé polymnesis-cards', () async {
      await StorageService.saveCards([buildCard(id: 'unique')]);

      final raw = await readRawPref('polymnesis-cards');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List<dynamic>;
      expect(decoded.length, 1);
      expect((decoded.first as Map<String, dynamic>)['id'], 'unique');
    });
  });

  group('StorageService - credentials de synchronisation', () {
    test('saveSyncCredentials puis loadSyncCredentials round-trip', () async {
      final creds = SyncCredentials(
        url: 'https://exemple.supabase.co',
        key: 'cle-secrete',
        // On garde enabled=false : aucune synchro réseau en environnement de test.
        enabled: false,
      );

      await StorageService.saveSyncCredentials(creds);
      final loaded = StorageService.loadSyncCredentials();

      expect(loaded.url, 'https://exemple.supabase.co');
      expect(loaded.key, 'cle-secrete');
      expect(loaded.enabled, isFalse);
      expect(loaded.isConfigured, isTrue);
    });

    test('loadSyncCredentials renvoie les valeurs par défaut quand absent', () {
      final loaded = StorageService.loadSyncCredentials();
      expect(loaded.url, '');
      expect(loaded.key, '');
      expect(loaded.enabled, isFalse);
      expect(loaded.isConfigured, isFalse);
    });

    test('loadSyncCredentials renvoie le défaut sur du JSON corrompu', () async {
      SharedPreferences.setMockInitialValues({kSyncCredsKey: 'not json{'});
      await StorageService.initialize();

      final loaded = silencePrints(() => StorageService.loadSyncCredentials());
      expect(loaded.url, '');
      expect(loaded.key, '');
      expect(loaded.enabled, isFalse);
    });

    test('saveSyncCredentials écrit bien sous la clé polymnesis-sync-creds',
        () async {
      await StorageService.saveSyncCredentials(
        SyncCredentials(url: 'u', key: 'k'),
      );

      final raw = await readRawPref('polymnesis-sync-creds');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['url'], 'u');
      expect(decoded['key'], 'k');
      expect(decoded['enabled'], isFalse);
    });
  });

  group('StorageService - paramètres Leitner', () {
    test('saveLeitnerSettings puis loadLeitnerSettings round-trip', () async {
      final settings = LeitnerSettings(intervals: const [2, 4, 8, 16]);

      await StorageService.saveLeitnerSettings(settings);
      final loaded = StorageService.loadLeitnerSettings();

      expect(loaded.intervals, const [2, 4, 8, 16]);
      expect(loaded.boxCount, 4);
    });

    test('loadLeitnerSettings renvoie les intervalles par défaut quand absent',
        () {
      final loaded = StorageService.loadLeitnerSettings();
      expect(loaded.intervals, LeitnerSettings.defaultIntervals);
      expect(loaded.boxCount, 6);
    });

    test('loadLeitnerSettings renvoie le défaut sur du JSON corrompu', () async {
      SharedPreferences.setMockInitialValues(
          {kLeitnerSettingsKey: 'not json{'});
      await StorageService.initialize();

      final loaded = silencePrints(() => StorageService.loadLeitnerSettings());
      expect(loaded.intervals, LeitnerSettings.defaultIntervals);
    });

    test(
        'saveLeitnerSettings écrit bien sous la clé polymnesis-leitner-settings',
        () async {
      await StorageService.saveLeitnerSettings(
        LeitnerSettings(intervals: const [5, 10]),
      );

      final raw = await readRawPref('polymnesis-leitner-settings');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['intervals'], const [5, 10]);
    });
  });
}
