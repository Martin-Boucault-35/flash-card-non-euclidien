import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/models/models.dart';
import 'package:polymnesis/screens/create_screen.dart';
import 'package:polymnesis/widgets/app_button.dart';

import '../helpers/test_helpers.dart';

/// Tests widget pour [CreateScreen] (écran de création / édition de carte).
///
/// Couverture :
///  - Mode création (provider.editingCard == null) :
///      * rendu du titre 'Nouvelle Carte' et du bouton 'Enregistrer la carte' ;
///      * validation : réponse vide -> 'La réponse est requise.' ;
///      * validation : triggers tous vides -> 'Il faut au moins un trigger.' ;
///      * soumission valide -> provider.addCard (cardCount +1, réponse saisie),
///        callback onSaved déclenché ;
///      * 'Ajouter' ajoute une ligne de trigger (un TextField de plus) ;
///      * l'icône supprimer retire une ligne (seulement quand > 1).
///  - Mode édition (setEditingCard avant le pump, postFrameCallback charge la
///    carte) :
///      * rendu du titre 'Modifier la carte' et champ réponse pré-rempli ;
///      * soumission -> saveCard (mise à jour, cardCount inchangé) + reset de
///        l'édition (editingCard == null).
///
/// Le 1er TextField est la réponse, les suivants sont les triggers.
/// Aucun timer périodique sur cet écran -> pumpAndSettle est sûr.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // addCard -> saveCard ; aucun flux notif ici, mais on installe le fake par
    // sécurité (et cohérence avec les conventions du projet).
    installFakeNotifications();
  });

  group('CreateScreen - mode création', () {
    testWidgets('affiche le titre "Nouvelle Carte" et le bouton d\'enregistrement',
        (tester) async {
      seedPrefs(cards: [buildCard(id: 'a')]);
      final provider = await makeInitializedProvider();

      await tester.pumpWidget(
        wrapWithProvider(
          CreateScreen(onCancel: () {}, onSaved: () {}),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle Carte'), findsOneWidget);
      expect(find.text('Modifier la carte'), findsNothing);
      expect(find.text('Enregistrer la carte'), findsOneWidget);
      // Réponse + 2 lignes de triggers par défaut = 3 TextField.
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('réponse vide affiche "La réponse est requise."',
        (tester) async {
      seedPrefs(cards: [buildCard(id: 'a')]);
      final provider = await makeInitializedProvider();

      await tester.pumpWidget(
        wrapWithProvider(
          CreateScreen(onCancel: () {}, onSaved: () {}),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // On remplit un trigger mais pas la réponse.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'Un indice');

      await tester.tap(find.text('Enregistrer la carte'));
      await tester.pumpAndSettle();

      expect(find.text('La réponse est requise.'), findsOneWidget);
      expect(provider.cardCount, 1); // aucune carte ajoutée
    });

    testWidgets('triggers tous vides affiche "Il faut au moins un trigger."',
        (tester) async {
      seedPrefs(cards: [buildCard(id: 'a')]);
      final provider = await makeInitializedProvider();

      await tester.pumpWidget(
        wrapWithProvider(
          CreateScreen(onCancel: () {}, onSaved: () {}),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Réponse remplie, triggers laissés vides.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Stromboli');

      await tester.tap(find.text('Enregistrer la carte'));
      await tester.pumpAndSettle();

      expect(find.text('Il faut au moins un trigger.'), findsOneWidget);
      expect(provider.cardCount, 1); // aucune carte ajoutée
    });

    testWidgets(
        'soumission valide ajoute la carte (cardCount +1) et déclenche onSaved',
        (tester) async {
      seedPrefs(cards: [buildCard(id: 'a', answer: 'Existante')]);
      final provider = await makeInitializedProvider();
      var savedCalled = false;

      await tester.pumpWidget(
        wrapWithProvider(
          CreateScreen(onCancel: () {}, onSaved: () => savedCalled = true),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      final before = provider.cardCount;

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Mont Fuji');
      await tester.enterText(fields.at(1), 'Volcan japonais');

      await tester.tap(find.text('Enregistrer la carte'));
      await tester.pumpAndSettle();

      expect(provider.cardCount, before + 1);
      expect(savedCalled, isTrue);
      // La nouvelle carte porte bien la réponse saisie.
      expect(
        provider.cards.any((c) => c.answer == 'Mont Fuji'),
        isTrue,
      );
      // Aucune erreur affichée après une soumission valide.
      expect(find.text('La réponse est requise.'), findsNothing);
      expect(find.text('Il faut au moins un trigger.'), findsNothing);
    });

    testWidgets('"Ajouter" ajoute une ligne de trigger (un TextField de plus)',
        (tester) async {
      seedPrefs(cards: [buildCard(id: 'a')]);
      final provider = await makeInitializedProvider();

      await tester.pumpWidget(
        wrapWithProvider(
          CreateScreen(onCancel: () {}, onSaved: () {}),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(3)); // 1 réponse + 2 triggers

      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(4)); // un trigger de plus
    });

    testWidgets(
        'l\'icône supprimer retire une ligne de trigger (quand plusieurs)',
        (tester) async {
      seedPrefs(cards: [buildCard(id: 'a')]);
      final provider = await makeInitializedProvider();

      await tester.pumpWidget(
        wrapWithProvider(
          CreateScreen(onCancel: () {}, onSaved: () {}),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // 2 triggers par défaut -> 2 icônes de suppression visibles.
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
      expect(find.byType(TextField), findsNWidgets(3));

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      // Plus qu'un trigger restant -> 2 TextField (réponse + 1 trigger).
      expect(find.byType(TextField), findsNWidgets(2));
      // Avec un seul trigger restant, l'icône de suppression disparaît.
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });

  group('CreateScreen - mode édition', () {
    testWidgets(
        'affiche "Modifier la carte" et pré-remplit le champ réponse',
        (tester) async {
      final card = buildCard(
        id: 'edit-1',
        theme: FlashCardTheme.histoire,
        answer: 'Napoléon',
        triggers: const ['Empereur', 'Austerlitz'],
      );
      seedPrefs(cards: [card]);
      final provider = await makeInitializedProvider();
      // On passe en mode édition AVANT le pump.
      provider.setEditingCard(card);

      await tester.pumpWidget(
        wrapWithProvider(
          CreateScreen(onCancel: () {}, onSaved: () {}),
          provider: provider,
        ),
      );
      // Frame supplémentaire pour exécuter le postFrameCallback (_loadEditingCard).
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Modifier la carte'), findsOneWidget);
      expect(find.text('Nouvelle Carte'), findsNothing);
      expect(find.text('Mettre à jour'), findsOneWidget);
      // En édition, le bouton "Annuler" est aussi présent.
      expect(find.text('Annuler'), findsOneWidget);

      // Champ réponse pré-rempli avec la réponse de la carte.
      final answerField =
          tester.widget<TextField>(find.byType(TextField).first);
      expect(answerField.controller!.text, 'Napoléon');
    });

    testWidgets(
        'soumission met à jour la carte (cardCount inchangé) et réinitialise l\'édition',
        (tester) async {
      final card = buildCard(
        id: 'edit-1',
        theme: FlashCardTheme.histoire,
        answer: 'Napoléon',
        triggers: const ['Empereur'],
      );
      seedPrefs(cards: [card, buildCard(id: 'other', answer: 'Autre')]);
      final provider = await makeInitializedProvider();
      provider.setEditingCard(card);

      var savedCalled = false;
      await tester.pumpWidget(
        wrapWithProvider(
          CreateScreen(onCancel: () {}, onSaved: () => savedCalled = true),
          provider: provider,
        ),
      );
      await tester.pump(); // postFrameCallback
      await tester.pumpAndSettle();

      final before = provider.cardCount;

      // On modifie la réponse.
      await tester.enterText(find.byType(TextField).first, 'Napoléon Bonaparte');
      await tester.tap(find.text('Mettre à jour'));
      await tester.pumpAndSettle();

      // Pas de nouvelle carte : c'est une mise à jour.
      expect(provider.cardCount, before);
      expect(savedCalled, isTrue);
      // L'édition est réinitialisée après sauvegarde.
      expect(provider.editingCard, isNull);
      // La carte d'id 'edit-1' porte désormais la nouvelle réponse.
      final updated = provider.cards.firstWhere((c) => c.id == 'edit-1');
      expect(updated.answer, 'Napoléon Bonaparte');
    });

    testWidgets('le bouton "Annuler" réinitialise l\'édition et appelle onCancel',
        (tester) async {
      final card = buildCard(id: 'edit-1', answer: 'Napoléon');
      seedPrefs(cards: [card]);
      final provider = await makeInitializedProvider();
      provider.setEditingCard(card);

      var cancelCalled = false;
      await tester.pumpWidget(
        wrapWithProvider(
          CreateScreen(onCancel: () => cancelCalled = true, onSaved: () {}),
          provider: provider,
        ),
      );
      await tester.pump(); // postFrameCallback
      await tester.pumpAndSettle();

      // On cible le bouton "Annuler" (variante secondaire) précisément.
      final cancelButton = find.widgetWithText(AppButton, 'Annuler');
      expect(cancelButton, findsOneWidget);

      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
      expect(provider.editingCard, isNull);
    });
  });
}
