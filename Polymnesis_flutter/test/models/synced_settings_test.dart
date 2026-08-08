// Tests de [SyncedSettings] (#42) — l'enveloppe des réglages synchronisés.
//
// Le point central : les timestamps sont PAR SECTION. Changer le jeton sur un
// appareil ne doit jamais écraser un réglage Leitner plus récent fait sur un
// autre — chaque section suit sa propre horloge.

import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/models/models.dart';

void main() {
  SyncedSettings settings({
    List<int> intervals = const [1, 3, 7, 14, 30, 90],
    int golden = 5,
    int leitnerAt = 0,
    String token = '',
    int ltdsAt = 0,
  }) =>
      SyncedSettings(
        leitner: LeitnerSettings(intervals: intervals, goldenSeconds: golden),
        leitnerUpdatedAt: leitnerAt,
        ltds: LtdsSettings(token: token),
        ltdsUpdatedAt: ltdsAt,
      );

  group('SyncedSettings - sérialisation', () {
    test('round-trip JSON complet', () {
      final s = settings(
        intervals: const [2, 4],
        golden: 9,
        leitnerAt: 111,
        token: 'tok',
        ltdsAt: 222,
      );
      final round = SyncedSettings.fromJson(s.toJson());

      expect(round.leitner.intervals, [2, 4]);
      expect(round.leitner.goldenSeconds, 9);
      expect(round.leitnerUpdatedAt, 111);
      expect(round.ltds.token, 'tok');
      expect(round.ltdsUpdatedAt, 222);
    });

    test('JSON incomplet -> défauts (rétro-compat)', () {
      final round = SyncedSettings.fromJson(const {});

      expect(round.leitner.intervals, LeitnerSettings.defaultIntervals);
      expect(round.leitnerUpdatedAt, 0);
      expect(round.ltds.token, '');
      expect(round.ltdsUpdatedAt, 0);
    });
  });

  group('SyncedSettings - merge par section', () {
    test('distant plus récent partout -> distant gagne partout', () {
      final local = settings(golden: 5, leitnerAt: 10, token: 'old', ltdsAt: 10);
      final remote =
          settings(golden: 9, leitnerAt: 20, token: 'new', ltdsAt: 20);

      final merged = local.merge(remote);

      expect(merged.leitner.goldenSeconds, 9);
      expect(merged.ltds.token, 'new');
      expect(merged.leitnerUpdatedAt, 20);
      expect(merged.ltdsUpdatedAt, 20);
    });

    test('sections croisées : chacune suit SA propre horloge', () {
      // Local : Leitner récent, jeton vieux. Distant : l'inverse.
      final local = settings(golden: 9, leitnerAt: 20, token: 'old', ltdsAt: 10);
      final remote =
          settings(golden: 5, leitnerAt: 10, token: 'new', ltdsAt: 20);

      final merged = local.merge(remote);

      expect(merged.leitner.goldenSeconds, 9); // local gagne
      expect(merged.ltds.token, 'new'); // distant gagne
    });

    test('à égalité, le local gagne (pas d\'écriture inutile)', () {
      final local = settings(golden: 9, leitnerAt: 10);
      final remote = settings(golden: 5, leitnerAt: 10);

      expect(local.merge(remote).leitner.goldenSeconds, 9);
      expect(local.newerThan(remote), isFalse);
    });

    test('newerThan : vrai dès qu\'UNE section locale est plus récente', () {
      final local = settings(leitnerAt: 10, ltdsAt: 30);
      final remote = settings(leitnerAt: 20, ltdsAt: 20);

      expect(local.newerThan(remote), isTrue); // ltds local plus récent
      expect(remote.newerThan(local), isTrue); // leitner distant plus récent
    });
  });
}
