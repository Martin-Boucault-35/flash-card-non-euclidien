import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/constants.dart';
import 'package:polymnesis/models/models.dart';

import '../helpers/test_helpers.dart';

/// Tests unitaires du [CardProvider].
///
/// Couverture :
/// - INIT : seed des 4 [initialCards] sur prefs vides, chargement des prefs semées,
///   drapeau isInitialized et cardCount.
/// - CRUD : addCard (insertion en tête, uuid non vide, trim de la réponse, drop des
///   indices vides), saveCard (mise à jour en place vs insertion en tête), deleteCard
///   (suppression et no-op sur id inconnu), édition courante (set/get/reset).
/// - QUERIES : filterCards (thème, boîte Leitner, recherche insensible à la casse sur
///   réponse OU indice, combinaison ET, terme vide/null), getCardCountForThemes,
///   getCardsForGame (longueur + appartenance au pool, jamais l'ordre car shuffle).
/// - LEITNER : getDailyCards (dues uniquement, exclusion des maîtrisées), leitnerCorrect
///   (+1, +2 easy, clamp vers maîtrisé avec nextReviewAt > now+9 ans), leitnerIncorrect
///   (recul borné à 1), updateLeitnerSettings (persistance + boxCount).
/// - SYNC : updateSyncCredentials(enabled:false) stocke sans toucher Supabase.
///
/// Convention : seedPrefs(...) AVANT makeInitializedProvider() dans chaque test.
/// provider.cards est non modifiable → on passe toujours par l'API publique.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Tout flux pouvant atteindre les notifications (markDailyCompleted, etc.)
  // exige une fausse plateforme installée, sinon LateInitializationError.
  setUp(() {
    installFakeNotifications();
  });

  group('CardProvider - initialisation', () {
    test('prefs vides => sème les 4 initialCards et passe isInitialized à true',
        () async {
      seedPrefs(); // aucun seed de cartes => premier lancement
      final provider = await makeInitializedProvider();

      expect(provider.isInitialized, isTrue);
      expect(provider.cardCount, initialCards.length);
      expect(provider.cardCount, 4);
      // Les ids des cartes par défaut sont présents.
      final ids = provider.cards.map((c) => c.id).toSet();
      expect(ids, containsAll(<String>{'1', '2', '3', '4'}));
    });

    test('prefs semées => charge exactement les cartes stockées', () async {
      seedPrefs(cards: [
        buildCard(id: 'a', answer: 'Alpha'),
        buildCard(id: 'b', answer: 'Beta'),
      ]);
      final provider = await makeInitializedProvider();

      expect(provider.isInitialized, isTrue);
      expect(provider.cardCount, 2);
      expect(provider.cards.map((c) => c.id), containsAll(<String>{'a', 'b'}));
    });

    test('sync désactivée par défaut, isSyncing reste false', () async {
      seedPrefs(cards: [buildCard()]);
      final provider = await makeInitializedProvider();

      expect(provider.isSyncing, isFalse);
      expect(provider.syncCredentials.enabled, isFalse);
    });
  });

  group('CardProvider - CRUD addCard', () {
    test('insère en tête, génère un uuid non vide et incrémente cardCount',
        () async {
      seedPrefs(cards: [buildCard(id: 'old', answer: 'Ancienne')]);
      final provider = await makeInitializedProvider();

      await provider.addCard(
        theme: FlashCardTheme.sciences,
        answer: 'Nouvelle',
        triggers: const ['indice'],
      );

      expect(provider.cardCount, 2);
      final first = provider.cards.first;
      expect(first.answer, 'Nouvelle');
      expect(first.theme, FlashCardTheme.sciences);
      expect(first.id, isNotEmpty);
      expect(first.id, isNot('old'));
    });

    test('trim la réponse et supprime les indices vides / espaces seuls',
        () async {
      seedPrefs(cards: []);
      final provider = await makeInitializedProvider();

      await provider.addCard(
        theme: FlashCardTheme.histoire,
        answer: '  Napoléon  ',
        triggers: const ['empereur', '', '   ', 'corse'],
      );

      final card = provider.cards.first;
      expect(card.answer, 'Napoléon');
      expect(card.triggers, ['empereur', 'corse']);
    });

    test('chaque addCard génère un id unique', () async {
      seedPrefs(cards: []);
      final provider = await makeInitializedProvider();

      await provider.addCard(
        theme: FlashCardTheme.sport,
        answer: 'A',
        triggers: const ['x'],
      );
      await provider.addCard(
        theme: FlashCardTheme.sport,
        answer: 'B',
        triggers: const ['y'],
      );

      final ids = provider.cards.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length); // tous distincts
    });
  });

  group('CardProvider - saveCard', () {
    test('id existant => mise à jour en place, cardCount inchangé', () async {
      seedPrefs(cards: [
        buildCard(id: 'a', answer: 'Avant'),
        buildCard(id: 'b', answer: 'Beta'),
      ]);
      final provider = await makeInitializedProvider();

      await provider.saveCard(buildCard(id: 'a', answer: 'Après'));

      expect(provider.cardCount, 2);
      final updated = provider.cards.firstWhere((c) => c.id == 'a');
      expect(updated.answer, 'Après');
    });

    test('id nouveau => insertion en tête', () async {
      seedPrefs(cards: [buildCard(id: 'a', answer: 'Alpha')]);
      final provider = await makeInitializedProvider();

      await provider.saveCard(buildCard(id: 'z', answer: 'Zeta'));

      expect(provider.cardCount, 2);
      expect(provider.cards.first.id, 'z');
    });
  });

  group('CardProvider - deleteCard', () {
    test('supprime la carte ciblée', () async {
      seedPrefs(cards: [
        buildCard(id: 'a'),
        buildCard(id: 'b'),
      ]);
      final provider = await makeInitializedProvider();

      await provider.deleteCard('a');

      expect(provider.cardCount, 1);
      expect(provider.cards.single.id, 'b');
    });

    test('id inconnu => aucune modification', () async {
      seedPrefs(cards: [buildCard(id: 'a'), buildCard(id: 'b')]);
      final provider = await makeInitializedProvider();

      await provider.deleteCard('inexistant');

      expect(provider.cardCount, 2);
    });
  });

  group('CardProvider - carte en édition', () {
    test('setEditingCard puis resetEditingCard', () async {
      seedPrefs(cards: [buildCard(id: 'a')]);
      final provider = await makeInitializedProvider();

      expect(provider.editingCard, isNull);

      final card = buildCard(id: 'a');
      provider.setEditingCard(card);
      expect(provider.editingCard, isNotNull);
      expect(provider.editingCard!.id, 'a');

      provider.resetEditingCard();
      expect(provider.editingCard, isNull);
    });
  });

  group('CardProvider - filterCards', () {
    Future<dynamic> seededProvider() {
      seedPrefs(cards: [
        buildCard(
            id: 'h1',
            theme: FlashCardTheme.histoire,
            answer: 'Charles V',
            triggers: const ['Roi sage'],
            leitnerBox: 1),
        buildCard(
            id: 'g1',
            theme: FlashCardTheme.geographie,
            answer: 'Stromboli',
            triggers: const ['Volcan Italie'],
            leitnerBox: 2),
        buildCard(
            id: 'h2',
            theme: FlashCardTheme.histoire,
            answer: 'George Sand',
            triggers: const ['Aurore Dupin'],
            leitnerBox: 3),
      ]);
      return makeInitializedProvider();
    }

    test('filtre par thème ne garde que ce thème', () async {
      final provider = await seededProvider();
      final result = provider.filterCards(theme: FlashCardTheme.histoire);
      expect(result.map((c) => c.id), containsAll(<String>{'h1', 'h2'}));
      expect(result.every((c) => c.theme == FlashCardTheme.histoire), isTrue);
      expect(result.length, 2);
    });

    test('filtre par boîte Leitner ne garde que cette boîte', () async {
      final provider = await seededProvider();
      final result = provider.filterCards(leitnerBox: 2);
      expect(result.length, 1);
      expect(result.single.id, 'g1');
    });

    test('recherche insensible à la casse sur la réponse', () async {
      final provider = await seededProvider();
      final result = provider.filterCards(searchTerm: 'CHARLES');
      expect(result.length, 1);
      expect(result.single.id, 'h1');
    });

    test('recherche correspond aussi à un indice', () async {
      final provider = await seededProvider();
      final result = provider.filterCards(searchTerm: 'volcan');
      expect(result.length, 1);
      expect(result.single.id, 'g1');
    });

    test('filtres combinés sont en ET', () async {
      final provider = await seededProvider();
      final result = provider.filterCards(
        theme: FlashCardTheme.histoire,
        searchTerm: 'sand',
      );
      expect(result.length, 1);
      expect(result.single.id, 'h2');
    });

    test('terme vide ou null renvoie toutes les cartes', () async {
      final provider = await seededProvider();
      expect(provider.filterCards(searchTerm: '').length, 3);
      expect(provider.filterCards().length, 3);
    });
  });

  group('CardProvider - getCardCountForThemes', () {
    Future<dynamic> seededProvider() {
      seedPrefs(cards: [
        buildCard(id: 'h1', theme: FlashCardTheme.histoire),
        buildCard(id: 'h2', theme: FlashCardTheme.histoire),
        buildCard(id: 'g1', theme: FlashCardTheme.geographie),
      ]);
      return makeInitializedProvider();
    }

    test('liste vide => total des cartes', () async {
      final provider = await seededProvider();
      expect(provider.getCardCountForThemes(<String>[]), 3);
    });

    test('un thème => nombre de cartes correspondantes', () async {
      final provider = await seededProvider();
      expect(provider.getCardCountForThemes(['Histoire']), 2);
      expect(provider.getCardCountForThemes(['Géographie']), 1);
    });

    test('plusieurs thèmes => somme des correspondances', () async {
      final provider = await seededProvider();
      expect(provider.getCardCountForThemes(['Histoire', 'Géographie']), 3);
    });
  });

  group('CardProvider - getCardsForGame (shuffle: on teste taille + appartenance)',
      () {
    test('liste vide de thèmes => min(count, total) cartes du pool', () async {
      seedPrefs(cards: [
        buildCard(id: 'a'),
        buildCard(id: 'b'),
        buildCard(id: 'c'),
      ]);
      final provider = await makeInitializedProvider();

      final two = provider.getCardsForGame([], 2);
      expect(two.length, 2);
      // count > total => borné au total
      final tooMany = provider.getCardsForGame([], 99);
      expect(tooMany.length, 3);
      // Toutes proviennent du pool connu.
      final poolIds = {'a', 'b', 'c'};
      expect(tooMany.every((c) => poolIds.contains(c.id)), isTrue);
    });

    test('thème filtré => uniquement les cartes de ce thème', () async {
      seedPrefs(cards: [
        buildCard(id: 'h1', theme: FlashCardTheme.histoire),
        buildCard(id: 'h2', theme: FlashCardTheme.histoire),
        buildCard(id: 'g1', theme: FlashCardTheme.geographie),
      ]);
      final provider = await makeInitializedProvider();

      final result = provider.getCardsForGame(['Histoire'], 10);
      expect(result.length, 2);
      expect(result.every((c) => c.theme == FlashCardTheme.histoire), isTrue);
      expect(result.map((c) => c.id), containsAll(<String>{'h1', 'h2'}));
    });
  });

  group('CardProvider - getDailyCards', () {
    test('ne garde que les cartes dues et exclut les maîtrisées', () async {
      // boxCount par défaut = 6 ; une carte en boîte 7 est "maîtrisée".
      seedPrefs(cards: [
        buildCard(id: 'due1', nextReviewAt: daysFromNowMillis(-1)),
        buildCard(id: 'due2', nextReviewAt: daysFromNowMillis(-10)),
        buildCard(id: 'pasdue', nextReviewAt: daysFromNowMillis(5)),
        buildCard(
            id: 'maitrisee',
            leitnerBox: 7,
            nextReviewAt: daysFromNowMillis(-1)),
      ]);
      final provider = await makeInitializedProvider();

      final daily = provider.getDailyCards();
      final ids = daily.map((c) => c.id).toSet();
      expect(ids, containsAll(<String>{'due1', 'due2'}));
      expect(ids.contains('pasdue'), isFalse);
      expect(ids.contains('maitrisee'), isFalse); // exclue car box > boxCount
      expect(provider.dailyCardCount, 2);
    });
  });

  group('CardProvider - Leitner réponses', () {
    test('leitnerCorrect normal => boîte +1', () async {
      seedPrefs(cards: [buildCard(id: 'a', leitnerBox: 2)]);
      final provider = await makeInitializedProvider();

      await provider.leitnerCorrect(provider.cards.single);

      expect(provider.cards.single.leitnerBox, 3);
    });

    test('leitnerCorrect easy => boîte +2', () async {
      seedPrefs(cards: [buildCard(id: 'a', leitnerBox: 2)]);
      final provider = await makeInitializedProvider();

      await provider.leitnerCorrect(provider.cards.single, easy: true);

      expect(provider.cards.single.leitnerBox, 4);
    });

    test('leitnerCorrect près du sommet => maîtrisée (clamp boxCount+1) avec '
        'nextReviewAt très lointain', () async {
      // box 6 + 2 (easy) clampé à boxCount+1 = 7 => maîtrisée.
      seedPrefs(cards: [buildCard(id: 'a', leitnerBox: 6)]);
      final provider = await makeInitializedProvider();

      await provider.leitnerCorrect(provider.cards.single, easy: true);

      final card = provider.cards.single;
      expect(card.leitnerBox, 7); // boxCount(6) + 1
      // nextReviewAt ~ now + 10 ans => bien au-delà de now + 9 ans.
      expect(card.nextReviewAt, greaterThan(daysFromNowMillis(365 * 9)));
    });

    // NOTE : le bonus "rapide" (+2) du jeu dépend du temps réel écoulé et ne peut
    // pas être piloté par pump/fakeAsync. Ici on cible directement l'API publique
    // leitnerCorrect(easy:...) pour couvrir les deux chemins de façon déterministe.

    test('leitnerIncorrect => boîte -1', () async {
      seedPrefs(cards: [buildCard(id: 'a', leitnerBox: 4)]);
      final provider = await makeInitializedProvider();

      await provider.leitnerIncorrect(provider.cards.single);

      expect(provider.cards.single.leitnerBox, 3);
    });

    test('leitnerIncorrect depuis la boîte 1 reste à 1', () async {
      seedPrefs(cards: [buildCard(id: 'a', leitnerBox: 1)]);
      final provider = await makeInitializedProvider();

      await provider.leitnerIncorrect(provider.cards.single);

      expect(provider.cards.single.leitnerBox, 1);
    });

    test('leitnerCorrect (non maîtrisée) reprogramme nextReviewAt selon '
        'l\'intervalle de la nouvelle boîte', () async {
      // box 1 -> 2 ; intervalle par défaut de la boîte 2 = 3 jours (intervals[1]).
      seedPrefs(cards: [buildCard(id: 'a', leitnerBox: 1)]);
      final provider = await makeInitializedProvider();

      await provider.leitnerCorrect(provider.cards.single);

      final card = provider.cards.single;
      expect(card.leitnerBox, 2);
      // Tolérance large car computeNextReview s'appuie sur DateTime.now().
      expect(
        card.nextReviewAt,
        closeTo(daysFromNowMillis(3), const Duration(hours: 2).inMilliseconds),
      );
    });

    test('leitnerCorrect normal peut atteindre la boîte maîtrisée (6 -> 7)',
        () async {
      seedPrefs(cards: [buildCard(id: 'a', leitnerBox: 6)]);
      final provider = await makeInitializedProvider();

      await provider.leitnerCorrect(provider.cards.single); // +1

      final card = provider.cards.single;
      expect(card.leitnerBox, 7); // boxCount(6) + 1 => maîtrisée
      expect(card.nextReviewAt, greaterThan(daysFromNowMillis(365 * 9)));
    });

    test('leitnerIncorrect reprogramme nextReviewAt (bientôt) selon la boîte',
        () async {
      // box 4 -> 3 ; intervalle par défaut de la boîte 3 = 7 jours (intervals[2]).
      seedPrefs(cards: [
        buildCard(id: 'a', leitnerBox: 4, nextReviewAt: daysFromNowMillis(30)),
      ]);
      final provider = await makeInitializedProvider();

      await provider.leitnerIncorrect(provider.cards.single);

      final card = provider.cards.single;
      expect(card.leitnerBox, 3);
      expect(
        card.nextReviewAt,
        closeTo(daysFromNowMillis(7), const Duration(hours: 2).inMilliseconds),
      );
    });

    test('leitnerIncorrect depuis une carte maîtrisée (7) revient à la dernière '
        'boîte (6)', () async {
      seedPrefs(cards: [buildCard(id: 'a', leitnerBox: 7)]);
      final provider = await makeInitializedProvider();

      await provider.leitnerIncorrect(provider.cards.single);

      // (7 - 1).clamp(1, boxCount=6) => 6.
      expect(provider.cards.single.leitnerBox, 6);
    });
  });

  // Vérifie que CHAQUE boîte suit le bon « workflow » de révision espacée :
  // la période d'attente (nextReviewAt) doit correspondre à l'intervalle de la
  // boîte d'arrivée, aussi bien en cas de bonne que de mauvaise réponse.
  group('CardProvider - planification des intervalles par boîte', () {
    // Intervalles par défaut [1,3,7,14,30,90] => getIntervalDays(box) = intervals[box-1].
    const daysForBox = {1: 1, 2: 3, 3: 7, 4: 14, 5: 30, 6: 90};
    const tolMs = 2 * 60 * 60 * 1000; // 2 h de tolérance (DateTime.now()).

    for (final startBox in [1, 2, 3, 4, 5]) {
      final newBox = startBox + 1;
      test('bonne réponse en boîte $startBox => boîte $newBox planifiée à '
          '${daysForBox[newBox]} jours', () async {
        seedPrefs(cards: [buildCard(id: 'a', leitnerBox: startBox)]);
        final provider = await makeInitializedProvider();

        await provider.leitnerCorrect(provider.cards.single); // +1 (normal)

        final card = provider.cards.single;
        expect(card.leitnerBox, newBox);
        expect(
          card.nextReviewAt,
          closeTo(daysFromNowMillis(daysForBox[newBox]!), tolMs),
          reason: 'boîte $newBox doit être revue dans ${daysForBox[newBox]} jours',
        );
      });
    }

    for (final startBox in [2, 3, 4, 5, 6]) {
      final newBox = startBox - 1;
      test('mauvaise réponse en boîte $startBox => boîte $newBox planifiée à '
          '${daysForBox[newBox]} jours', () async {
        // nextReviewAt initial lointain pour bien voir qu'il est avancé.
        seedPrefs(cards: [
          buildCard(
              id: 'a',
              leitnerBox: startBox,
              nextReviewAt: daysFromNowMillis(100)),
        ]);
        final provider = await makeInitializedProvider();

        await provider.leitnerIncorrect(provider.cards.single); // -1

        final card = provider.cards.single;
        expect(card.leitnerBox, newBox);
        expect(
          card.nextReviewAt,
          closeTo(daysFromNowMillis(daysForBox[newBox]!), tolMs),
          reason: 'boîte $newBox doit être revue dans ${daysForBox[newBox]} jours',
        );
      });
    }

    test('session mixte : une boîte 2 et une boîte 5 réussies suivent chacune '
        'leur propre période (7 j et 90 j)', () async {
      // Scénario décrit : dans un même jeu quotidien, des cartes de boîtes
      // différentes ; chacune doit être replanifiée selon SA boîte d'arrivée.
      seedPrefs(cards: [
        buildCard(id: 'recente', leitnerBox: 2, nextReviewAt: 1000),
        buildCard(id: 'ancienne', leitnerBox: 5, nextReviewAt: 1000),
      ]);
      final provider = await makeInitializedProvider();

      // Les deux sont dues aujourd'hui.
      expect(provider.getDailyCards().map((c) => c.id).toSet(),
          {'recente', 'ancienne'});

      final b2 = provider.cards.firstWhere((c) => c.id == 'recente');
      final b5 = provider.cards.firstWhere((c) => c.id == 'ancienne');
      await provider.leitnerCorrect(b2); // 2 -> 3 (7 j)
      await provider.leitnerCorrect(b5); // 5 -> 6 (90 j)

      final r = provider.cards.firstWhere((c) => c.id == 'recente');
      final a = provider.cards.firstWhere((c) => c.id == 'ancienne');
      expect(r.leitnerBox, 3);
      expect(r.nextReviewAt,
          closeTo(daysFromNowMillis(7), const Duration(hours: 2).inMilliseconds));
      expect(a.leitnerBox, 6);
      expect(a.nextReviewAt,
          closeTo(daysFromNowMillis(90), const Duration(hours: 2).inMilliseconds));

      // Elles ne sont plus dues aujourd'hui (replanifiées dans le futur).
      expect(provider.getDailyCards(), isEmpty);
    });
  });

  group('CardProvider - updateLeitnerSettings', () {
    test('persiste les nouveaux paramètres et change boxCount', () async {
      seedPrefs(cards: [buildCard()]);
      final provider = await makeInitializedProvider();
      expect(provider.leitnerSettings.boxCount, 6); // défaut

      await provider.updateLeitnerSettings(
        LeitnerSettings(intervals: const [1, 5, 10]),
      );

      expect(provider.leitnerSettings.boxCount, 3);
      expect(provider.leitnerSettings.intervals, [1, 5, 10]);

      // Persistance dans les prefs.
      final raw = await readRawPref(kLeitnerSettingsKey);
      expect(raw, isNotNull);
      expect(raw, contains('10'));
    });
  });

  group('CardProvider - sync (chemin désactivé uniquement)', () {
    test('updateSyncCredentials(enabled:false) stocke sans toucher Supabase',
        () async {
      seedPrefs(cards: [buildCard()]);
      final provider = await makeInitializedProvider();

      await provider.updateSyncCredentials(
        SyncCredentials(url: 'https://x', key: 'k', enabled: false),
      );

      expect(provider.syncCredentials.enabled, isFalse);
      expect(provider.syncCredentials.url, 'https://x');
      expect(provider.isSyncing, isFalse);

      final raw = await readRawPref(kSyncCredsKey);
      expect(raw, isNotNull);
      expect(raw, contains('https://x'));
    });
  });
}
