// Tests widget de [CardDetailScreen] (#27) et de l'ouverture depuis le Pokédex.
//
// La page travaille par `cardId` et lit le provider : elle reste donc à jour si
// la carte change. Les tests montent la page directement (via wrapWithProvider,
// qui fournit un Navigator réel) ou passent par CollectionScreen pour vérifier
// la navigation au tap.

import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/models/models.dart';
import 'package:polymnesis/screens/card_detail_screen.dart';
import 'package:polymnesis/screens/collection_screen.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    installFakeNotifications();
  });

  /// Carte riche : variantes d'import + historique de 3 événements.
  FlashCard richCard() => buildCard(
        id: 'paris',
        theme: FlashCardTheme.geographie,
        answer: 'Paris',
        triggers: const ['Tour Eiffel', 'Capitale'],
        leitnerBox: 3,
        history: [
          buildEvent(type: CardEventType.imported, fromBox: 1, toBox: 1, at: 1000),
          buildEvent(type: CardEventType.correct, fromBox: 1, toBox: 2, at: 2000),
          buildEvent(
              type: CardEventType.correctFast, fromBox: 2, toBox: 4, at: 3000),
        ],
      );

  Future<void> pumpDetail(WidgetTester tester, {String id = 'paris'}) async {
    final provider = await makeInitializedProvider();
    await tester.pumpWidget(
      wrapWithProvider(CardDetailScreen(cardId: id), provider: provider),
    );
    await tester.pumpAndSettle();
  }

  group('CardDetailScreen - contenu', () {
    testWidgets('affiche réponse, indices et compteur d\'historique',
        (tester) async {
      seedPrefs(cards: [richCard()]);
      await pumpDetail(tester);

      expect(find.text('Détail de la carte'), findsOneWidget);
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Tour Eiffel'), findsOneWidget);
      expect(find.text('Capitale'), findsOneWidget);
      expect(find.text('Indices (2)'), findsOneWidget);
      expect(find.text('Historique (3)'), findsOneWidget);
    });

    testWidgets('affiche les réponses acceptées quand il y en a', (tester) async {
      final card = FlashCard(
        id: 'z',
        theme: FlashCardTheme.sport,
        answer: 'Zidane',
        triggers: const ['numéro 10'],
        createdAt: 1000,
        acceptedAnswers: const ['Zidane', 'zizou'],
      );
      seedPrefs(cards: [card]);
      await pumpDetail(tester, id: 'z');

      expect(find.text('Réponses acceptées'), findsOneWidget);
      expect(find.text('zizou'), findsOneWidget);
    });

    testWidgets('sans variantes, la section n\'apparaît pas', (tester) async {
      seedPrefs(cards: [buildCard(id: 'simple', answer: 'Simple')]);
      await pumpDetail(tester, id: 'simple');

      expect(find.text('Réponses acceptées'), findsNothing);
    });
  });

  group('CardDetailScreen - historique', () {
    testWidgets('pile antichronologique : la dernière action est en haut',
        (tester) async {
      seedPrefs(cards: [richCard()]);
      await pumpDetail(tester);

      // Les 3 libellés d'événements sont présents...
      expect(find.text('Carte importée'), findsOneWidget);
      expect(find.text('Bonne réponse'), findsOneWidget);
      expect(find.text('Réponse rapide'), findsOneWidget);

      // ...et le plus récent (Réponse rapide, at:3000) est au-dessus du plus
      // ancien (Carte importée, at:1000).
      final fastY = tester.getTopLeft(find.text('Réponse rapide')).dy;
      final importedY = tester.getTopLeft(find.text('Carte importée')).dy;
      expect(fastY, lessThan(importedY));
    });

    testWidgets('affiche le mouvement de boîte', (tester) async {
      seedPrefs(cards: [richCard()]);
      await pumpDetail(tester);

      expect(find.textContaining('boîte 2 → 4'), findsOneWidget);
    });

    testWidgets('carte jamais révisée : seulement son événement d\'origine',
        (tester) async {
      // Depuis la migration #34, toute carte reçoit un événement d'origine au
      // chargement : l'état "aucun historique" n'est donc plus atteignable en
      // pratique. Une carte neuve montre son origine, et rien d'autre.
      seedPrefs(cards: [buildCard(id: 'neuve', answer: 'Neuve')]);
      await pumpDetail(tester, id: 'neuve');

      expect(find.text('Historique (1)'), findsOneWidget);
      expect(find.text('Carte ajoutée'), findsOneWidget);
    });

    testWidgets('carte introuvable (supprimée) : message dédié', (tester) async {
      seedPrefs(cards: [buildCard(id: 'autre')]);
      await pumpDetail(tester, id: 'inexistante');

      expect(find.text('Carte introuvable.'), findsOneWidget);
    });
  });

  group('CollectionScreen - ouverture du détail (#27)', () {
    testWidgets('taper une carte ouvre sa page de détail', (tester) async {
      seedPrefs(cards: [richCard()]);
      final provider = await makeInitializedProvider();
      await tester.pumpWidget(
        wrapWithProvider(
          CollectionScreen(onEdit: (_) {}),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // On est bien sur le Pokédex, pas encore sur le détail.
      expect(find.text('Mon Pokédex'), findsOneWidget);
      expect(find.text('Détail de la carte'), findsNothing);

      await tester.tap(find.text('Paris'));
      await tester.pumpAndSettle();

      expect(find.text('Détail de la carte'), findsOneWidget);
      expect(find.text('Historique (3)'), findsOneWidget);
    });
  });
}
