import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/models/card_model.dart';
import 'package:polymnesis/services/sync_reconciler.dart';

/// Tests de [reconcileCards] — le cœur de la sync sans perte ni doublon.
void main() {
  FlashCard card({
    required String id,
    required String answer,
    List<String> triggers = const ['t'],
    List<String> acceptedAnswers = const [],
    int leitnerBox = 1,
    int createdAt = 100,
    int? updatedAt,
    FlashCardTheme theme = FlashCardTheme.cultureG,
  }) =>
      FlashCard(
        id: id,
        theme: theme,
        answer: answer,
        triggers: triggers,
        acceptedAnswers: acceptedAnswers,
        leitnerBox: leitnerBox,
        createdAt: createdAt,
        updatedAt: updatedAt ?? createdAt,
      );

  group('déduplication par réponse', () {
    test('même réponse, ids différents → 1 carte fusionnée', () {
      final local = [
        card(id: 'L', answer: 'Mozart', triggers: ['indice A'], createdAt: 50, updatedAt: 100, leitnerBox: 1),
      ];
      final remote = [
        card(id: 'R', answer: 'mozart', triggers: ['indice B'], acceptedAnswers: ['mozart', 'mozzart'], createdAt: 60, updatedAt: 200, leitnerBox: 4),
      ];

      final r = reconcileCards(local: local, remote: remote);

      expect(r.merged.length, 1);
      final m = r.merged.single;
      expect(m.id, 'L'); // plus ancienne createdAt → id stable
      expect(m.triggers, ['indice A', 'indice B']); // union, ordre préservé
      expect(m.acceptedAnswers, ['mozart', 'mozzart']);
      expect(m.leitnerBox, 4); // updatedAt le plus récent (200) gagne
      expect(m.updatedAt, 200);
      expect(m.createdAt, 50);
      // R devient un orphelin distant à supprimer ; la carte fusionnée est poussée.
      expect(r.remoteOrphanIds, ['R']);
      expect(r.toUpsert.map((c) => c.id), contains('L'));
    });

    test('même id des deux côtés, distant plus frais → pas de ré-écriture', () {
      final local = [card(id: 'X', answer: 'Foo', leitnerBox: 1, updatedAt: 100)];
      final remote = [card(id: 'X', answer: 'Foo', leitnerBox: 5, updatedAt: 300)];

      final r = reconcileCards(local: local, remote: remote);

      expect(r.merged.single.leitnerBox, 5);
      expect(r.remoteOrphanIds, isEmpty);
      expect(r.toUpsert, isEmpty); // rien n'a changé vs le distant
    });
  });

  group('poussée du local manquant', () {
    test('carte locale absente du distant → à upserter', () {
      final r = reconcileCards(
        local: [card(id: 'X', answer: 'Alpha')],
        remote: const [],
      );
      expect(r.merged.length, 1);
      expect(r.toUpsert.map((c) => c.id), ['X']);
      expect(r.remoteOrphanIds, isEmpty);
    });

    test('restauration : local vide + distant plein → tout redescend', () {
      final remote = [
        card(id: 'A', answer: 'Alpha'),
        card(id: 'B', answer: 'Beta'),
      ];
      final r = reconcileCards(local: const [], remote: remote);
      expect(r.merged.map((c) => c.answer).toSet(), {'Alpha', 'Beta'});
      expect(r.remoteOrphanIds, isEmpty);
      expect(r.toUpsert, isEmpty); // déjà identiques au distant
    });
  });

  group('cartes de démo pristines', () {
    test('écartées quand le distant a du contenu', () {
      final local = [
        card(id: 'seed', answer: 'Demo'),
        card(id: 'L', answer: 'Alpha'),
      ];
      final remote = [card(id: 'R', answer: 'Beta')];

      final r = reconcileCards(
        local: local,
        remote: remote,
        isPristineSeed: (c) => c.id == 'seed',
      );

      expect(r.merged.map((c) => c.answer).toSet(), {'Alpha', 'Beta'});
      expect(r.merged.any((c) => c.answer == 'Demo'), isFalse);
    });

    test('conservées si le distant est vide (premier envoi)', () {
      final r = reconcileCards(
        local: [card(id: 'seed', answer: 'Demo')],
        remote: const [],
        isPristineSeed: (c) => c.id == 'seed',
      );
      expect(r.merged.single.answer, 'Demo');
    });
  });

  group('idempotence', () {
    test('rejouer la réconciliation ne change plus rien', () {
      final local = [card(id: 'L', answer: 'Mozart', triggers: ['a'], updatedAt: 100)];
      final remote = [card(id: 'R', answer: 'Mozart', triggers: ['b'], updatedAt: 200)];

      final first = reconcileCards(local: local, remote: remote);
      // Après application : local ET remote deviennent l'état fusionné.
      final second = reconcileCards(local: first.merged, remote: first.merged);

      expect(second.toUpsert, isEmpty);
      expect(second.remoteOrphanIds, isEmpty);
      expect(second.merged.length, 1);
    });
  });
}
