import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/models/ltds_settings.dart';

/// Tests du modèle [LtdsSettings].
///
/// Couverture : valeurs par défaut, copyWith, (de)sérialisation JSON,
/// et le getter isConfigured (jeton vide / espaces => non configuré).
void main() {
  group('LtdsSettings', () {
    test('valeurs par défaut : token vide, non configuré', () {
      final s = LtdsSettings();
      expect(s.token, '');
      expect(s.isConfigured, isFalse);
    });

    test('isConfigured ignore les espaces', () {
      expect(LtdsSettings(token: '   ').isConfigured, isFalse);
      expect(LtdsSettings(token: 'abc').isConfigured, isTrue);
    });

    test('copyWith remplace le token', () {
      final s = LtdsSettings(token: 'a');
      expect(s.copyWith(token: 'b').token, 'b');
      expect(s.copyWith().token, 'a');
    });

    test('toJson / fromJson sont symétriques', () {
      final s = LtdsSettings(token: 'eyJxyz');
      final round = LtdsSettings.fromJson(s.toJson());
      expect(round.token, 'eyJxyz');
    });

    test('fromJson tolère un token absent', () {
      expect(LtdsSettings.fromJson(const {}).token, '');
    });
  });
}
