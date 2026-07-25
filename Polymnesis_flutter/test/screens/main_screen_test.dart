// Tests widget de [MainScreen] — la coquille de navigation à onglets de
// lib/main.dart.
//
// Couverture :
//  - Une fois le provider initialisé, l'AppBar affiche 'PolyMnesis' et la barre
//    de navigation expose les 5 labels (Accueil, Créer, Pokédex, Jouer,
//    Quotidien).
//  - L'item Pokédex porte un badge égal à provider.cardCount (3 cartes semées
//    => badge '3').
//  - La navigation entre onglets affiche le contenu unique de chaque écran de
//    destination (Accueil -> 'Mémoire Non-Euclidienne', Créer -> 'Nouvelle
//    Carte', Pokédex -> 'Mon Pokédex', Jouer -> 'Configuration de la Partie',
//    Quotidien -> vue Ready 'Révision espacée — Système Leitner').
//
// On assert sur le contenu *unique* de chaque destination plutôt que sur le
// label de navigation (qui apparaît aussi parfois dans le corps de l'écran,
// ex. 'Jeu Quotidien' est un titre de carte sur l'accueil ET le titre de la
// vue Ready du quotidien).
//
// GOTCHA timer : on n'appuie jamais sur "démarrer" du jeu quotidien — la vue
// Ready n'a pas de Timer.periodic, donc pumpAndSettle est sûr ici. On reste sur
// la vue Ready et on vérifie seulement son contenu.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:polymnesis/main.dart';
import 'package:polymnesis/providers/card_provider.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // markDailyCompleted / écran quotidien peuvent toucher aux notifications :
  // on installe une fausse plateforme no-op pour éviter LateInitializationError.
  setUp(() {
    installFakeNotifications();
  });

  // Monte MainScreen avec un provider déjà initialisé et un jeu de cartes connu.
  // Les cartes sont volontairement "non dues" (nextReviewAt dans le futur) pour
  // que dailyCardCount soit 0 — ainsi seul le badge Pokédex (== cardCount)
  // apparaît, ce qui rend l'assertion sur '3' déterministe.
  Future<CardProvider> mountMainScreen(WidgetTester tester) async {
    seedPrefs(cards: [
      buildCard(id: 'a', nextReviewAt: daysFromNowMillis(5)),
      buildCard(id: 'b', nextReviewAt: daysFromNowMillis(5)),
      buildCard(id: 'c', nextReviewAt: daysFromNowMillis(5)),
    ]);
    final provider = await makeInitializedProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<CardProvider>.value(
        value: provider,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  group('MainScreen - état initialisé', () {
    testWidgets('affiche le titre PolyMnesis et les 5 labels de navigation',
        (tester) async {
      final provider = await mountMainScreen(tester);

      expect(provider.isInitialized, isTrue);
      // 'PolyMnesis' apparaît dans le titre de l'AppBar.
      expect(find.text('PolyMnesis'), findsOneWidget);

      for (final label in const [
        'Accueil',
        'Créer',
        'Pokédex',
        'Jouer',
        'Quotidien',
      ]) {
        expect(find.text(label), findsOneWidget,
            reason: 'le label de nav "$label" doit être présent');
      }
    });

    testWidgets("démarre sur l'accueil (Mémoire Non-Euclidienne)",
        (tester) async {
      await mountMainScreen(tester);
      expect(find.text('Mémoire Non-Euclidienne'), findsOneWidget);
    });

    testWidgets('le badge Pokédex vaut le nombre de cartes (3)',
        (tester) async {
      final provider = await mountMainScreen(tester);
      expect(provider.cardCount, 3);
      // Le badge '3' du Pokédex est visible dans la barre de navigation.
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('MainScreen - navigation entre onglets', () {
    testWidgets('Pokédex affiche "Mon Pokédex"', (tester) async {
      await mountMainScreen(tester);

      await tester.tap(find.text('Pokédex'));
      await tester.pumpAndSettle();

      expect(find.text('Mon Pokédex'), findsOneWidget);
    });

    testWidgets('Jouer affiche "Configuration de la Partie"', (tester) async {
      await mountMainScreen(tester);

      await tester.tap(find.text('Jouer'));
      await tester.pumpAndSettle();

      expect(find.text('Configuration de la Partie'), findsOneWidget);
    });

    testWidgets('Créer affiche "Nouvelle Carte"', (tester) async {
      await mountMainScreen(tester);

      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle Carte'), findsOneWidget);
    });

    testWidgets('Quotidien affiche la vue Ready du jeu quotidien',
        (tester) async {
      await mountMainScreen(tester);

      await tester.tap(find.text('Quotidien'));
      // La vue Ready n'a pas de Timer.periodic : pumpAndSettle est sûr tant
      // qu'on ne démarre pas la partie.
      await tester.pumpAndSettle();

      // Texte unique à la vue Ready (et non au corps de l'accueil).
      expect(find.text('Révision espacée — Système Leitner'), findsOneWidget);
    });

    testWidgets('retour sur Accueil après navigation', (tester) async {
      await mountMainScreen(tester);

      // Aller sur le Pokédex puis revenir à l'accueil.
      await tester.tap(find.text('Pokédex'));
      await tester.pumpAndSettle();
      expect(find.text('Mon Pokédex'), findsOneWidget);

      await tester.tap(find.text('Accueil'));
      await tester.pumpAndSettle();
      expect(find.text('Mémoire Non-Euclidienne'), findsOneWidget);
      // Le contenu du Pokédex n'est plus affiché.
      expect(find.text('Mon Pokédex'), findsNothing);
    });
  });

  group('MainScreen - actions de la coquille', () {
    testWidgets('le bouton paramètres ouvre la modale "Paramètres"',
        (tester) async {
      await mountMainScreen(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // _openSettings() a présenté la SettingsModal (avec ses onglets).
      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Leitner'), findsOneWidget);
    });

    testWidgets(
        'éditer une carte depuis le Pokédex ouvre l\'écran de modification',
        (tester) async {
      await mountMainScreen(tester);

      await tester.tap(find.text('Pokédex'));
      await tester.pumpAndSettle();

      // _handleEditCard -> setEditingCard + navigation vers l'écran Créer.
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Modifier la carte'), findsOneWidget);
    });
  });

  group('MainScreen - état non initialisé', () {
    testWidgets('affiche le splash (logo + chargement) tant que non initialisé',
        (tester) async {
      seedPrefs(cards: [buildCard()]);
      // Provider volontairement NON initialisé : isInitialized == false.
      final provider = CardProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<CardProvider>.value(
          value: provider,
          child: const MaterialApp(home: MainScreen()),
        ),
      );
      await tester.pump(); // un seul pump : l'init n'a pas été lancée.

      expect(provider.isInitialized, isFalse);
      expect(find.text('PolyMnesis'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Pas encore de barre de navigation pendant le splash.
      expect(find.text('Accueil'), findsNothing);

      // On termine l'init pour ne laisser aucune future pendante et vérifier la
      // bascule vers l'UI complète.
      await provider.initialize();
      await tester.pumpAndSettle();
      expect(find.text('Mémoire Non-Euclidienne'), findsOneWidget);
    });
  });
}
