import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:polymnesis/models/models.dart';
import 'package:polymnesis/providers/card_provider.dart';
import 'package:polymnesis/services/ltds_import_service.dart';

import '../helpers/test_helpers.dart';

/// Tests de [CardProvider.importFromLtds].
///
/// Couverture :
/// - création de cartes depuis les deux niveaux (abordable + expert) avec mapping
///   de thème (Musiques -> Moderne) ;
/// - fusion par réponse : une réponse déjà connue ajoute un indice au lieu de
///   créer un doublon ;
/// - idempotence : rejouer le même import ne crée ni carte ni indice ;
/// - jeton absent -> LtdsAuthException ;
/// - 401 -> LtdsAuthException ;
/// - aucun jour joué (404) -> résultat vide.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    installFakeNotifications();
  });

  /// Réponse 200 encodée UTF-8.
  http.Response ok(Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  /// Mock renvoyant un payload par chemin d'URL, 404 sinon.
  MockClient clientFor(Map<String, Object> byPath) {
    return MockClient((req) async {
      final body = byPath[req.url.path];
      if (body == null) {
        return http.Response(jsonEncode({'statusCode': 404}), 404);
      }
      return ok(body);
    });
  }

  Object dayWith(List<Map<String, Object>> questions) => {
        'day': {'dayNumber': 152, 'questions': questions},
      };

  Map<String, Object> q(int order, String text, String theme, String answer) => {
        'order': order,
        'text': text,
        'theme': theme,
        'validAnswers': [answer],
      };

  // Carte sentinelle : un seed NON vide est nécessaire, car le provider sème
  // ses 4 cartes par défaut quand le stockage est vide ("premier lancement").
  // Sa réponse n'entre en collision avec aucune donnée d'import.
  FlashCard sentinel() =>
      buildCard(id: 'seed', answer: '__sentinelle__', triggers: const ['x']);

  group('importFromLtds - création', () {
    test('crée des cartes depuis les deux niveaux avec les bons thèmes',
        () async {
      seedPrefs(cards: [sentinel()]);
      final provider = await makeInitializedProvider();
      await provider.updateLtdsSettings(LtdsSettings(token: 'tok'));

      final client = clientFor({
        '/game/facile/152': dayWith([
          q(1, 'Inventeur de Dracula ?', 'Classique', 'Dracula'),
          q(2, 'Chanteur de Papaoutai ?', 'Musiques', 'Stromae'),
        ]),
        '/game/difficile/152': dayWith([
          q(1, 'Pays du Kim-Vân-Kiêu ?', 'Histoire', 'Vietnam'),
        ]),
      });

      final result = await provider.importFromLtds(days: [152], client: client);

      expect(result.questionsFound, 3);
      expect(result.cardsCreated, 3);
      expect(result.triggersAdded, 0);
      expect(result.daysWithData, [152]);
      expect(provider.cardCount, 4); // sentinelle + 3 nouvelles

      final stromae = provider.cards.firstWhere((c) => c.answer == 'Stromae');
      expect(stromae.theme, FlashCardTheme.moderne); // Musiques -> Moderne
      final dracula = provider.cards.firstWhere((c) => c.answer == 'Dracula');
      expect(dracula.theme, FlashCardTheme.classique);
      expect(dracula.triggers, ['Inventeur de Dracula ?']);
    });
  });

  group('importFromLtds - réponses acceptées', () {
    test('stocke toutes les validAnswers et matchesAnswer les reconnaît',
        () async {
      seedPrefs(cards: [sentinel()]);
      final provider = await makeInitializedProvider();
      await provider.updateLtdsSettings(LtdsSettings(token: 'tok'));

      final client = clientFor({
        '/game/facile/152': dayWith([
          {
            'order': 1,
            'text': 'Ballon d\'or 1957 ?',
            'theme': 'Sport',
            'validAnswers': ['Alfredo Di Stefano', 'di stefano', 'distephano'],
          },
        ]),
      });

      await provider.importFromLtds(days: [152], client: client);
      final card =
          provider.cards.firstWhere((c) => c.answer == 'Alfredo Di Stefano');

      expect(card.acceptedAnswers,
          ['Alfredo Di Stefano', 'di stefano', 'distephano']);
      // La correction accepte les variantes mal écrites.
      expect(card.matchesAnswer('di stefano'), isTrue);
      expect(card.matchesAnswer('Distephano'), isTrue);
    });

    test('fusionne les nouvelles variantes sur une carte existante', () async {
      seedPrefs(cards: [
        buildCard(id: 'd', answer: 'Banane', triggers: const ['fruit jaune']),
      ]);
      final provider = await makeInitializedProvider();
      await provider.updateLtdsSettings(LtdsSettings(token: 'tok'));

      final client = clientFor({
        '/game/facile/152': dayWith([
          {
            'order': 1,
            'text': 'Fruit des musacées ?',
            'theme': 'Animaux et plantes',
            'validAnswers': ['Banane', 'la banane', 'bananes'],
          },
        ]),
      });

      final result =
          await provider.importFromLtds(days: [152], client: client);
      final card = provider.cards.single;

      expect(card.acceptedAnswers, containsAll(['la banane', 'bananes']));
      expect(card.matchesAnswer('la banane'), isTrue);
      // Backfill : les variantes ajoutées sont comptées (utile pour ré-importer
      // d'anciennes cartes créées avant cette fonctionnalité).
      expect(result.acceptedAnswersAdded, greaterThan(0));
      expect(result.summary, contains('variante'));
    });
  });

  group('importFromLtds - fusion par réponse', () {
    test('une réponse déjà connue ajoute un indice au lieu d\'un doublon',
        () async {
      seedPrefs(cards: [
        buildCard(id: 'd', answer: 'Dracula', triggers: const ['Roman de 1897']),
      ]);
      final provider = await makeInitializedProvider();
      await provider.updateLtdsSettings(LtdsSettings(token: 'tok'));

      final client = clientFor({
        '/game/facile/152': dayWith([
          q(1, 'Inventeur de Dracula ?', 'Classique', 'Dracula'),
        ]),
      });

      final result = await provider.importFromLtds(days: [152], client: client);

      expect(result.cardsCreated, 0);
      expect(result.triggersAdded, 1);
      expect(provider.cardCount, 1);
      final card = provider.cards.single;
      expect(card.triggers, ['Roman de 1897', 'Inventeur de Dracula ?']);
    });

    test('la correspondance de réponse ignore la casse', () async {
      seedPrefs(cards: [buildCard(id: 'd', answer: 'dracula')]);
      final provider = await makeInitializedProvider();
      await provider.updateLtdsSettings(LtdsSettings(token: 'tok'));

      final client = clientFor({
        '/game/facile/152': dayWith([
          q(1, 'Inventeur de Dracula ?', 'Classique', 'Dracula'),
        ]),
      });

      final result = await provider.importFromLtds(days: [152], client: client);
      expect(result.cardsCreated, 0);
      expect(result.triggersAdded, 1);
    });
  });

  group('importFromLtds - idempotence', () {
    test('rejouer le même import ne crée ni carte ni indice', () async {
      seedPrefs(cards: [sentinel()]);
      final provider = await makeInitializedProvider();
      await provider.updateLtdsSettings(LtdsSettings(token: 'tok'));

      final client = clientFor({
        '/game/facile/152': dayWith([
          q(1, 'Inventeur de Dracula ?', 'Classique', 'Dracula'),
        ]),
      });

      final first = await provider.importFromLtds(days: [152], client: client);
      final second = await provider.importFromLtds(days: [152], client: client);

      expect(first.cardsCreated, 1);
      expect(second.cardsCreated, 0);
      expect(second.triggersAdded, 0);
      expect(provider.cardCount, 2); // sentinelle + Dracula
    });
  });

  group('importFromLtds - erreurs', () {
    test('jeton vide -> LtdsAuthException', () async {
      seedPrefs(cards: []);
      final provider = await makeInitializedProvider();
      // pas de updateLtdsSettings : jeton vide

      final client = clientFor({});
      expect(
        () => provider.importFromLtds(days: [152], client: client),
        throwsA(isA<LtdsAuthException>()),
      );
    });

    test('401 -> LtdsAuthException', () async {
      seedPrefs(cards: []);
      final provider = await makeInitializedProvider();
      await provider.updateLtdsSettings(LtdsSettings(token: 'bad'));

      final client = MockClient(
        (_) async => http.Response(jsonEncode({'statusCode': 401}), 401),
      );
      expect(
        () => provider.importFromLtds(days: [152], client: client),
        throwsA(isA<LtdsAuthException>()),
      );
    });

    test('aucun jour joué (404) -> résultat vide', () async {
      seedPrefs(cards: [sentinel()]);
      final provider = await makeInitializedProvider();
      await provider.updateLtdsSettings(LtdsSettings(token: 'tok'));

      final client = clientFor({}); // tout en 404
      final result = await provider.importFromLtds(days: [200], client: client);

      expect(result.questionsFound, 0);
      expect(result.cardsCreated, 0);
      expect(result.daysWithData, isEmpty);
      expect(result.daysWithoutData, [200]);
      expect(provider.cardCount, 1); // inchangé (sentinelle seule)
      expect(result.summary, contains('Pas d\'historique'));
      expect(result.summary, contains('200'));
    });
  });
}
