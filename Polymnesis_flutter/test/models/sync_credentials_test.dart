import 'package:flutter_test/flutter_test.dart';
import 'package:polymnesis/models/sync_credentials.dart';

/// Tests unitaires de [SyncCredentials] (modèle pur, sans I/O ni réseau).
///
/// Couverture :
/// - Valeurs par défaut (url/key vides, enabled=false) et isConfigured=false.
/// - isConfigured vrai uniquement si url ET key sont non vides
///   (cas url seule, key seule, les deux).
/// - copyWith ne surcharge que les champs fournis.
/// - toJson expose url/key/enabled ; fromJson fait l'aller-retour et
///   applique les valeurs par défaut sur les champs manquants.
void main() {
  group('SyncCredentials - valeurs par défaut', () {
    test('url et key vides, enabled false, non configuré', () {
      final creds = SyncCredentials();
      expect(creds.url, '');
      expect(creds.key, '');
      expect(creds.enabled, isFalse);
      expect(creds.isConfigured, isFalse);
    });
  });

  group('SyncCredentials - isConfigured', () {
    test('vrai seulement si url ET key sont renseignées', () {
      final creds = SyncCredentials(url: 'https://x.supabase.co', key: 'abc');
      expect(creds.isConfigured, isTrue);
    });

    test('faux si url seule est renseignée', () {
      final creds = SyncCredentials(url: 'https://x.supabase.co', key: '');
      expect(creds.isConfigured, isFalse);
    });

    test('faux si key seule est renseignée', () {
      final creds = SyncCredentials(url: '', key: 'abc');
      expect(creds.isConfigured, isFalse);
    });

    test('faux si url et key sont vides', () {
      final creds = SyncCredentials(url: '', key: '');
      expect(creds.isConfigured, isFalse);
    });

    test('isConfigured indépendant de enabled', () {
      // enabled=false n'empêche pas isConfigured=true (deux notions distinctes).
      final creds = SyncCredentials(
        url: 'https://x.supabase.co',
        key: 'abc',
        enabled: false,
      );
      expect(creds.enabled, isFalse);
      expect(creds.isConfigured, isTrue);
    });
  });

  group('SyncCredentials.copyWith', () {
    final base = SyncCredentials(
      url: 'https://base.supabase.co',
      key: 'base-key',
      enabled: true,
    );

    test('sans argument renvoie une copie équivalente', () {
      final copy = base.copyWith();
      expect(copy.url, base.url);
      expect(copy.key, base.key);
      expect(copy.enabled, base.enabled);
    });

    test('surcharge uniquement les champs fournis', () {
      final copy = base.copyWith(enabled: false);
      expect(copy.enabled, isFalse);
      // inchangés
      expect(copy.url, 'https://base.supabase.co');
      expect(copy.key, 'base-key');
    });

    test('surcharge url et key seules', () {
      final copy = base.copyWith(url: 'https://new.supabase.co', key: 'new-key');
      expect(copy.url, 'https://new.supabase.co');
      expect(copy.key, 'new-key');
      // enabled inchangé
      expect(copy.enabled, isTrue);
    });
  });

  group('SyncCredentials.toJson / fromJson', () {
    test('toJson expose url, key et enabled', () {
      final json = SyncCredentials(
        url: 'https://x.supabase.co',
        key: 'abc',
        enabled: true,
      ).toJson();
      expect(json['url'], 'https://x.supabase.co');
      expect(json['key'], 'abc');
      expect(json['enabled'], isTrue);
    });

    test('round-trip toJson -> fromJson préserve les champs', () {
      final creds = SyncCredentials(
        url: 'https://x.supabase.co',
        key: 'secret-key',
        enabled: true,
      );
      final restored = SyncCredentials.fromJson(creds.toJson());
      expect(restored.url, creds.url);
      expect(restored.key, creds.key);
      expect(restored.enabled, creds.enabled);
      expect(restored.isConfigured, isTrue);
    });

    test('fromJson applique les valeurs par défaut sur champs manquants', () {
      final creds = SyncCredentials.fromJson(<String, dynamic>{});
      expect(creds.url, '');
      expect(creds.key, '');
      expect(creds.enabled, isFalse);
      expect(creds.isConfigured, isFalse);
    });

    test('fromJson lit les champs partiels fournis', () {
      final creds = SyncCredentials.fromJson(<String, dynamic>{
        'url': 'https://partial.supabase.co',
      });
      expect(creds.url, 'https://partial.supabase.co');
      expect(creds.key, '');
      expect(creds.enabled, isFalse);
    });
  });
}
