// Tests widget de [CollectionScreen] (le "Pokédex").
//
// Couverture :
//  - rendu de l'en-tête 'Mon Pokédex' et de toutes les réponses des cartes semées ;
//  - champ de recherche : filtre par réponse ET par indice (trigger),
//    insensible à la casse ;
//  - filtre par thème via le DropdownButton<FlashCardTheme?> ;
//  - filtre par boîte Leitner via le DropdownButton<int?> ;
//  - état vide ('Aucune carte trouvée.') quand aucun filtre ne correspond ;
//  - suppression : l'icône delete ouvre l'AlertDialog 'Supprimer cette carte ?',
//    'Supprimer' appelle deleteCard (cardCount diminue), 'Annuler' annule ;
//  - l'icône edit déclenche le callback onEdit avec la bonne carte.
//
// Conventions : seedPrefs + makeInitializedProvider + wrapWithProvider, et
// installFakeNotifications dans setUp (le provider peut toucher aux notifs).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/models/models.dart';
import 'package:polymnesis/screens/collection_screen.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    installFakeNotifications();
  });

  // Jeu de cartes connu réutilisé par la plupart des tests.
  // - Paris : Géographie, boîte 1, indice 'Tour Eiffel'
  // - Lyon : Géographie, boîte 3
  // - Napoléon : Histoire, boîte 1, indice 'Empereur des Français'
  List<FlashCard> seedCards() => [
        buildCard(
          id: 'paris',
          theme: FlashCardTheme.geographie,
          answer: 'Paris',
          triggers: const ['Tour Eiffel', 'Capitale'],
          leitnerBox: 1,
        ),
        buildCard(
          id: 'lyon',
          theme: FlashCardTheme.geographie,
          answer: 'Lyon',
          triggers: const ['Fourvière'],
          leitnerBox: 3,
        ),
        buildCard(
          id: 'napoleon',
          theme: FlashCardTheme.histoire,
          answer: 'Napoléon',
          triggers: const ['Empereur des Français', 'Austerlitz'],
          leitnerBox: 1,
        ),
      ];

  Future<void> pumpCollection(
    WidgetTester tester, {
    required void Function(FlashCard) onEdit,
  }) async {
    final provider = await makeInitializedProvider();
    await tester.pumpWidget(
      wrapWithProvider(
        CollectionScreen(onEdit: onEdit),
        provider: provider,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CollectionScreen - rendu', () {
    testWidgets("affiche l'en-tête 'Mon Pokédex' et toutes les réponses",
        (tester) async {
      seedPrefs(cards: seedCards());
      await pumpCollection(tester, onEdit: (_) {});

      expect(find.text('Mon Pokédex'), findsOneWidget);
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Lyon'), findsOneWidget);
      expect(find.text('Napoléon'), findsOneWidget);
    });
  });

  group('CollectionScreen - recherche', () {
    testWidgets('filtre par réponse (insensible à la casse)', (tester) async {
      seedPrefs(cards: seedCards());
      await pumpCollection(tester, onEdit: (_) {});

      // Le premier TextField est le champ de recherche.
      await tester.enterText(find.byType(TextField).first, 'paris');
      await tester.pumpAndSettle();

      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Lyon'), findsNothing);
      expect(find.text('Napoléon'), findsNothing);
    });

    testWidgets('filtre par indice (trigger)', (tester) async {
      seedPrefs(cards: seedCards());
      await pumpCollection(tester, onEdit: (_) {});

      // 'Empereur' n'apparaît que dans les triggers de Napoléon.
      await tester.enterText(find.byType(TextField).first, 'empereur');
      await tester.pumpAndSettle();

      expect(find.text('Napoléon'), findsOneWidget);
      expect(find.text('Paris'), findsNothing);
      expect(find.text('Lyon'), findsNothing);
    });

    testWidgets('aucune correspondance => état vide', (tester) async {
      seedPrefs(cards: seedCards());
      await pumpCollection(tester, onEdit: (_) {});

      await tester.enterText(find.byType(TextField).first, 'zzzinexistant');
      await tester.pumpAndSettle();

      expect(find.text('Aucune carte trouvée.'), findsOneWidget);
      expect(find.text('Paris'), findsNothing);
      expect(find.text('Lyon'), findsNothing);
      expect(find.text('Napoléon'), findsNothing);
    });
  });

  group('CollectionScreen - filtre par thème', () {
    testWidgets('sélectionner Histoire ne garde que les cartes Histoire',
        (tester) async {
      seedPrefs(cards: seedCards());
      await pumpCollection(tester, onEdit: (_) {});

      await tester.tap(find.byType(DropdownButton<FlashCardTheme?>));
      await tester.pumpAndSettle();

      // Le menu ouvert propose les displayName des thèmes.
      // 'Histoire' apparaît dans le menu déroulant — on tape la dernière
      // occurrence (l'item du menu, par-dessus le reste de l'UI).
      await tester.tap(find.text('Histoire').last);
      await tester.pumpAndSettle();

      expect(find.text('Napoléon'), findsOneWidget);
      expect(find.text('Paris'), findsNothing);
      expect(find.text('Lyon'), findsNothing);
    });
  });

  group('CollectionScreen - filtre par boîte', () {
    testWidgets('sélectionner Boîte 3 ne garde que les cartes de la boîte 3',
        (tester) async {
      seedPrefs(cards: seedCards());
      await pumpCollection(tester, onEdit: (_) {});

      await tester.tap(find.byType(DropdownButton<int?>));
      await tester.pumpAndSettle();

      // Seule Lyon est en boîte 3. On tape l'item 'Boîte 3' du menu.
      await tester.tap(find.text('Boîte 3').last);
      await tester.pumpAndSettle();

      expect(find.text('Lyon'), findsOneWidget);
      expect(find.text('Paris'), findsNothing);
      expect(find.text('Napoléon'), findsNothing);
    });
  });

  group('CollectionScreen - suppression', () {
    testWidgets("l'icône delete ouvre la boîte de dialogue de confirmation",
        (tester) async {
      seedPrefs(cards: seedCards());
      await pumpCollection(tester, onEdit: (_) {});

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cette carte ?'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
    });

    testWidgets("'Supprimer' supprime la carte (cardCount diminue)",
        (tester) async {
      seedPrefs(cards: seedCards());
      final provider = await makeInitializedProvider();
      await tester.pumpWidget(
        wrapWithProvider(
          CollectionScreen(onEdit: (_) {}),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      expect(provider.cardCount, 3);

      // Supprime la première carte de la liste.
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(provider.cardCount, 2);
      expect(find.text('Supprimer cette carte ?'), findsNothing);
    });

    testWidgets("'Annuler' ferme la boîte sans rien supprimer", (tester) async {
      seedPrefs(cards: seedCards());
      final provider = await makeInitializedProvider();
      await tester.pumpWidget(
        wrapWithProvider(
          CollectionScreen(onEdit: (_) {}),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      expect(provider.cardCount, 3);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(provider.cardCount, 3);
      expect(find.text('Supprimer cette carte ?'), findsNothing);
    });
  });

  group('CollectionScreen - édition', () {
    testWidgets("l'icône edit appelle onEdit avec la bonne carte",
        (tester) async {
      seedPrefs(cards: seedCards());
      FlashCard? edited;
      await pumpCollection(tester, onEdit: (c) => edited = c);

      // La première carte semée (id 'paris') est la première de la liste.
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(edited, isNotNull);
      expect(edited!.id, 'paris');
      expect(edited!.answer, 'Paris');
    });
  });
}
