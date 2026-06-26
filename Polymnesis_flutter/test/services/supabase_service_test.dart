import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/models/models.dart';
import 'package:polymnesis/services/supabase_service.dart';

import '../helpers/test_helpers.dart';

/// Tests de la logique de GARDE de [SupabaseService] (statique).
///
/// Couverture :
///  - [SupabaseService.isReady] vaut `false` tant qu'aucune init réussie.
///  - [SupabaseService.initialize] refuse les credentials désactivés.
///  - [SupabaseService.initialize] refuse les credentials non configurés
///    (url/key vides) même avec `enabled:true`.
///  - [SupabaseService.reinitialize] refuse de même les credentials
///    désactivés / non configurés.
///  - [SupabaseService.fetchRemoteCards] / [upsertCard] / [deleteCard]
///    renvoient `null`/`false` SANS lever d'exception quand le service
///    n'est pas prêt.
///
/// NOTE: aucun réseau ni vrai `Supabase.initialize` n'est sollicité ici.
/// On ne teste QUE les branches de garde (jamais `enabled:true` avec une
/// url/key plausibles, ce qui tenterait une vraie initialisation Supabase).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseService - état initial', () {
    test('isReady est false avant toute initialisation', () {
      expect(SupabaseService.isReady, isFalse);
    });
  });

  group('SupabaseService.initialize - branches de garde', () {
    test('credentials désactivés (enabled:false) => false, isReady false',
        () async {
      final creds = SyncCredentials(
        url: 'https://example.supabase.co',
        key: 'cle-quelconque',
        enabled: false,
      );

      final result = await SupabaseService.initialize(creds);

      expect(result, isFalse);
      expect(SupabaseService.isReady, isFalse);
    });

    test(
        'credentials non configurés (url/key vides) avec enabled:true => false, '
        'isReady false', () async {
      final creds = SyncCredentials(url: '', key: '', enabled: true);

      // isConfigured == false (url et key vides) => garde déclenchée.
      expect(creds.isConfigured, isFalse);

      final result = await SupabaseService.initialize(creds);

      expect(result, isFalse);
      expect(SupabaseService.isReady, isFalse);
    });

    test('url vide mais key fournie (toujours non configuré) => false',
        () async {
      final creds = SyncCredentials(url: '', key: 'cle', enabled: true);

      expect(creds.isConfigured, isFalse);

      final result = await SupabaseService.initialize(creds);

      expect(result, isFalse);
      expect(SupabaseService.isReady, isFalse);
    });
  });

  group('SupabaseService.reinitialize - branches de garde', () {
    test('credentials désactivés => false, isReady false', () async {
      final creds = SyncCredentials(
        url: 'https://example.supabase.co',
        key: 'cle-quelconque',
        enabled: false,
      );

      final result = await SupabaseService.reinitialize(creds);

      expect(result, isFalse);
      expect(SupabaseService.isReady, isFalse);
    });

    test('credentials non configurés (enabled:true, vides) => false', () async {
      final creds = SyncCredentials(url: '', key: '', enabled: true);

      final result = await SupabaseService.reinitialize(creds);

      expect(result, isFalse);
      expect(SupabaseService.isReady, isFalse);
    });
  });

  group('SupabaseService - opérations refusées quand non prêt', () {
    // Le service n'a jamais été initialisé avec succès (toutes les branches
    // ci-dessus remettent _isInitialized=false / _client=null), donc isReady
    // reste false et les opérations court-circuitent sans toucher au réseau.
    test('fetchRemoteCards renvoie null sans lever', () async {
      expect(SupabaseService.isReady, isFalse);

      final cards = await SupabaseService.fetchRemoteCards();

      expect(cards, isNull);
    });

    test('upsertCard renvoie false sans lever', () async {
      expect(SupabaseService.isReady, isFalse);

      final card = buildCard();
      final ok = await SupabaseService.upsertCard(card);

      expect(ok, isFalse);
    });

    test('deleteCard renvoie false sans lever', () async {
      expect(SupabaseService.isReady, isFalse);

      final ok = await SupabaseService.deleteCard('c1');

      expect(ok, isFalse);
    });
  });
}
