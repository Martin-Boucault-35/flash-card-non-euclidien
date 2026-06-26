import 'package:flutter_test/flutter_test.dart';
import 'package:polymnesis/models/leitner_settings.dart';

/// Tests unitaires de [LeitnerSettings].
///
/// Couverture :
///  - [LeitnerSettings.defaultIntervals] == [1,3,7,14,30,90] et constructeur par défaut.
///  - boxCount == longueur des intervalles ; copie défensive de la liste fournie.
///  - getIntervalDays(box) : bornes (0, 1, 6, 7) et hors-plage -> intervals.last.
///  - computeNextReview(box) : timestamp ~ now + getIntervalDays(box) jours
///    (fenêtre de tolérance, pas d'égalité exacte car DateTime.now() réel).
///  - boxLabel(box, maxBox) statique : 'Maîtrisé' si box > maxBox, sinon 'Boîte $box'.
///  - copyWith : surcharge des intervalles, conservation et copie défensive.
///  - toJson / fromJson : round-trip et repli sur defaultIntervals si absent/vide.
void main() {
  group('LeitnerSettings - construction et valeurs par défaut', () {
    test('defaultIntervals vaut [1,3,7,14,30,90]', () {
      expect(LeitnerSettings.defaultIntervals, [1, 3, 7, 14, 30, 90]);
    });

    test('constructeur par défaut utilise les intervalles par défaut', () {
      final s = LeitnerSettings();
      expect(s.intervals, [1, 3, 7, 14, 30, 90]);
    });

    test('boxCount vaut 6 par défaut (longueur des intervalles)', () {
      expect(LeitnerSettings().boxCount, 6);
    });

    test('boxCount suit la longueur des intervalles fournis', () {
      expect(LeitnerSettings(intervals: [1, 2, 3]).boxCount, 3);
    });

    test('le constructeur NE copie PAS la liste fournie (référence partagée)', () {
      // Comportement réel : `intervals = intervals ?? List.from(defaultIntervals)`.
      // Une liste explicitement fournie n'est PAS copiée — la référence est
      // partagée. (Seul le fallback par défaut est copié.) On documente ce fait :
      // muter la source d'origine se répercute donc sur l'instance.
      final source = <int>[1, 5, 10];
      final s = LeitnerSettings(intervals: source);
      expect(identical(s.intervals, source), isTrue);
      source[0] = 999;
      expect(s.intervals, [999, 5, 10]);
    });
  });

  group('LeitnerSettings.getIntervalDays', () {
    final s = LeitnerSettings(); // [1,3,7,14,30,90]

    test('box dans 1..length renvoie intervals[box-1]', () {
      expect(s.getIntervalDays(1), 1);
      expect(s.getIntervalDays(2), 3);
      expect(s.getIntervalDays(3), 7);
      expect(s.getIntervalDays(4), 14);
      expect(s.getIntervalDays(5), 30);
      expect(s.getIntervalDays(6), 90);
    });

    test('box == 0 (sous la borne) retombe sur intervals.last', () {
      expect(s.getIntervalDays(0), 90);
    });

    test('box négatif retombe sur intervals.last', () {
      expect(s.getIntervalDays(-3), 90);
    });

    test('box == 7 (au-dessus de length=6) retombe sur intervals.last', () {
      expect(s.getIntervalDays(7), 90);
    });

    test('box très grand retombe sur intervals.last', () {
      expect(s.getIntervalDays(100), 90);
    });
  });

  group('LeitnerSettings.computeNextReview', () {
    // computeNextReview s'appuie sur DateTime.now() (horloge réelle) : on
    // vérifie une fenêtre autour de now + getIntervalDays(box) jours plutôt
    // qu'une égalité exacte.
    final s = LeitnerSettings(); // [1,3,7,14,30,90]

    void expectAroundDays(int box, int expectedDays) {
      final before = DateTime.now().millisecondsSinceEpoch;
      final next = s.computeNextReview(box);
      final after = DateTime.now().millisecondsSinceEpoch;

      // Doit être strictement dans le futur.
      expect(next, greaterThan(before));

      final dayMs = const Duration(days: 1).inMilliseconds;
      // Bornes théoriques en tenant compte du temps écoulé pendant l'appel.
      final lower = before + expectedDays * dayMs;
      final upper = after + expectedDays * dayMs;
      // Petite marge de sécurité (1s) pour l'exécution.
      expect(next, greaterThanOrEqualTo(lower - 1000));
      expect(next, lessThanOrEqualTo(upper + 1000));
    }

    test('box 1 -> environ now + 1 jour', () {
      expectAroundDays(1, 1);
    });

    test('box 3 -> environ now + 7 jours', () {
      expectAroundDays(3, 7);
    });

    test('box 6 -> environ now + 90 jours', () {
      expectAroundDays(6, 90);
    });

    test('box hors-plage utilise intervals.last (90 jours)', () {
      expectAroundDays(0, 90);
      expectAroundDays(99, 90);
    });
  });

  group('LeitnerSettings.boxLabel (statique)', () {
    test('box <= maxBox renvoie "Boîte \$box"', () {
      expect(LeitnerSettings.boxLabel(1, 6), 'Boîte 1');
      expect(LeitnerSettings.boxLabel(6, 6), 'Boîte 6');
    });

    test('box > maxBox renvoie "Maîtrisé"', () {
      expect(LeitnerSettings.boxLabel(7, 6), 'Maîtrisé');
      expect(LeitnerSettings.boxLabel(100, 6), 'Maîtrisé');
    });
  });

  group('LeitnerSettings.copyWith', () {
    test('copyWith(intervals:) surcharge les intervalles', () {
      final base = LeitnerSettings();
      final copy = base.copyWith(intervals: [2, 4, 8]);
      expect(copy.intervals, [2, 4, 8]);
      expect(copy.boxCount, 3);
      // L'original reste intact.
      expect(base.intervals, [1, 3, 7, 14, 30, 90]);
    });

    test('copyWith() conserve les intervalles existants', () {
      final base = LeitnerSettings(intervals: [1, 5, 9]);
      final copy = base.copyWith();
      expect(copy.intervals, [1, 5, 9]);
    });

    test('copyWith() effectue une copie défensive de la liste', () {
      final base = LeitnerSettings(intervals: [1, 5, 9]);
      final copy = base.copyWith();
      expect(identical(copy.intervals, base.intervals), isFalse);
    });
  });

  group('LeitnerSettings.toJson / fromJson', () {
    test('toJson expose la clé "intervals"', () {
      final json = LeitnerSettings(intervals: [1, 3, 7]).toJson();
      expect(json, {'intervals': [1, 3, 7]});
    });

    test('round-trip toJson -> fromJson préserve les intervalles', () {
      final original = LeitnerSettings(intervals: [1, 4, 9, 16]);
      final restored = LeitnerSettings.fromJson(original.toJson());
      expect(restored.intervals, [1, 4, 9, 16]);
      expect(restored.boxCount, 4);
    });

    test('round-trip sur les intervalles par défaut', () {
      final restored = LeitnerSettings.fromJson(LeitnerSettings().toJson());
      expect(restored.intervals, [1, 3, 7, 14, 30, 90]);
    });

    test('fromJson sans clé "intervals" retombe sur defaultIntervals', () {
      final s = LeitnerSettings.fromJson(<String, dynamic>{});
      expect(s.intervals, [1, 3, 7, 14, 30, 90]);
    });

    test('fromJson avec "intervals" null retombe sur defaultIntervals', () {
      final s = LeitnerSettings.fromJson({'intervals': null});
      expect(s.intervals, [1, 3, 7, 14, 30, 90]);
    });

    test('fromJson avec liste vide donne une liste vide (boxCount 0)', () {
      // Une liste explicitement vide est cast<int>() valide et non nulle :
      // elle est conservée telle quelle (pas de repli).
      final s = LeitnerSettings.fromJson({'intervals': <int>[]});
      expect(s.intervals, isEmpty);
      expect(s.boxCount, 0);
    });
  });
}
