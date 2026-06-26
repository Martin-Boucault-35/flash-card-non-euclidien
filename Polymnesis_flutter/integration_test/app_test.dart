// Tests d'intégration end-to-end de PolyMnesis.
//
// On NE lance PAS le vrai `main()` de lib/main.dart : il appelle
// NotificationService.initialize/requestPermission/scheduleDailyReminder et
// SystemChrome.setSystemUIOverlayStyle (chemins plateforme indisponibles en
// test). On reconstruit donc le MÊME arbre de widgets que `main()` :
//   ChangeNotifierProvider(create: CardProvider()..initialize(),
//     child: MaterialApp(theme: AppTheme.darkTheme, home: MainScreen()))
//
// Couverture (chaque scénario = un testWidgets, seed frais) :
//   1. Démarrage : splash (CircularProgressIndicator + 'PolyMnesis') puis
//      l'accueil 'Mémoire Non-Euclidienne' ; barre de navigation présente.
//   2. Créer puis retrouver : onglet 'Créer' -> saisie réponse + trigger ->
//      'Enregistrer la carte' -> onglet 'Pokédex' -> la réponse apparaît et le
//      badge du Pokédex (cardCount) a augmenté.
//   3. Partie libre complète : 'Jouer' -> 'Configuration de la Partie' ->
//      'Commencer' -> on passe ('Passer') chaque carte jusqu'à
//      'Session Terminée !'.
//
// Conventions / pièges (voir aussi commentaires inline) :
//   - Le helper partagé vit dans test/ (frère de integration_test/) ; on
//     l'importe en relatif. Le code applicatif est importé en package:.
//   - DateTime.now() est l'horloge réelle : on rend les cartes "due" via un
//     petit nextReviewAt passé (buildCard par défaut => nextReviewAt = 1000).
//   - La vue "playing" du jeu LIBRE n'a pas de Timer.periodic mais utilise des
//     Future.delayed (1500ms réponse / 1000ms skip) : on avance avec
//     tester.pump(Duration) explicite, jamais pumpAndSettle pendant le jeu.
//   - Sync TOUJOURS désactivée (défaut) => SupabaseService jamais appelé.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:polymnesis/main.dart';
import 'package:polymnesis/models/models.dart';
import 'package:polymnesis/providers/card_provider.dart';
import 'package:polymnesis/theme/app_theme.dart';

import '../test/helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Toute fin de partie / flux quotidien peut toucher aux notifications.
  setUp(() {
    installFakeNotifications();
  });

  /// Reconstruit l'arbre applicatif sans passer par le vrai `main()`.
  Widget buildApp() {
    return ChangeNotifierProvider<CardProvider>(
      create: (_) => CardProvider()..initialize(),
      child: MaterialApp(
        title: 'PolyMnesis',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }

  /// Monte l'app et attend que le splash soit remplacé par l'accueil.
  Future<void> bootApp(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    // Pendant que le provider s'initialise, le splash affiche un loader.
    // On laisse le micro-tâches d'initialize() se résoudre puis on settle.
    await tester.pumpAndSettle();
    // L'accueil doit maintenant être visible.
    expect(find.text('Mémoire Non-Euclidienne'), findsOneWidget);
  }

  group('Scénario 1 — Démarrage de l\'application', () {
    testWidgets('affiche le splash puis l\'accueil avec la navigation',
        (tester) async {
      seedPrefs(cards: [
        buildCard(id: 's1', answer: 'Stromboli', theme: FlashCardTheme.geographie),
        buildCard(id: 's2', answer: 'Napoléon', theme: FlashCardTheme.histoire),
      ]);

      await tester.pumpWidget(buildApp());
      // Première frame : provider non initialisé => écran de splash.
      // (initialize() est asynchrone, donc isInitialized est encore false.)
      expect(find.text('PolyMnesis'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // On laisse l'initialisation se terminer.
      await tester.pumpAndSettle();

      // Accueil affiché, splash disparu.
      expect(find.text('Mémoire Non-Euclidienne'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // La barre de navigation expose les 5 onglets.
      expect(find.text('Accueil'), findsOneWidget);
      expect(find.text('Créer'), findsOneWidget);
      expect(find.text('Pokédex'), findsOneWidget);
      expect(find.text('Jouer'), findsOneWidget);
      expect(find.text('Quotidien'), findsOneWidget);
    });
  });

  group('Scénario 2 — Créer une carte puis la retrouver dans le Pokédex', () {
    testWidgets('la nouvelle carte apparaît et le badge Pokédex augmente',
        (tester) async {
      // Une seule carte au départ => badge Pokédex initial = "1".
      seedPrefs(cards: [
        buildCard(id: 'base', answer: 'CarteInitiale'),
      ]);
      await bootApp(tester);

      // Badge Pokédex (cardCount) de départ : "1".
      expect(find.text('1'), findsWidgets);

      // Onglet "Créer" -> écran de création.
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle Carte'), findsOneWidget);

      // Saisie de la réponse (premier TextField de l'écran de création).
      const nouvelleReponse = 'Vésuve';
      await tester.enterText(find.byType(TextField).first, nouvelleReponse);
      // Saisie d'un trigger (deuxième TextField : premier champ de trigger).
      await tester.enterText(find.byType(TextField).at(1), 'Volcan de Naples');
      await tester.pumpAndSettle();

      // Enregistrement.
      await tester.tap(find.text('Enregistrer la carte'));
      await tester.pumpAndSettle();

      // On reste sur l'écran de création après une création (cf. MainScreen).
      expect(find.text('Nouvelle Carte'), findsOneWidget);

      // Le badge Pokédex doit maintenant valoir "2" (1 initiale + 1 créée).
      expect(find.text('2'), findsWidgets);

      // Navigation vers le Pokédex.
      await tester.tap(find.text('Pokédex'));
      await tester.pumpAndSettle();
      expect(find.text('Mon Pokédex'), findsOneWidget);

      // La nouvelle réponse figure dans la liste.
      expect(find.text(nouvelleReponse), findsOneWidget);
      // L'ancienne carte est toujours là.
      expect(find.text('CarteInitiale'), findsOneWidget);
    });
  });

  group('Scénario 3 — Jouer une partie libre jusqu\'au bout', () {
    testWidgets('on passe chaque carte et on atteint "Session Terminée !"',
        (tester) async {
      // 3 cartes connues => questionCount par défaut (5) sera clampé à 3.
      seedPrefs(cards: [
        buildCard(id: 'g1', answer: 'Alpha', triggers: const ['Indice A']),
        buildCard(id: 'g2', answer: 'Beta', triggers: const ['Indice B']),
        buildCard(id: 'g3', answer: 'Gamma', triggers: const ['Indice C']),
      ]);
      await bootApp(tester);

      // Onglet "Jouer" -> écran de configuration.
      await tester.tap(find.text('Jouer'));
      await tester.pumpAndSettle();
      expect(find.text('Configuration de la Partie'), findsOneWidget);
      // Avec 3 cartes le total disponible doit s'afficher.
      expect(find.text('Total disponible: 3'), findsOneWidget);

      // Lancer la partie.
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      // Vue "playing" : le compteur de progression apparaît.
      // (Le pool est mélangé : on n'assert ni l'ordre ni la réponse exacte.)
      expect(find.textContaining('/ 3'), findsOneWidget);
      // Le bouton "Passer" est disponible pendant le jeu.
      expect(find.text('Passer'), findsOneWidget);

      // On passe les 3 cartes. "Passer" déclenche un feedback "wrong" puis
      // avance via Future.delayed(1000ms) : on pompe une durée explicite.
      // PAS de pumpAndSettle ici (présence de Future.delayed en cours).
      for (var i = 0; i < 3; i++) {
        expect(find.text('Passer'), findsOneWidget);
        await tester.tap(find.text('Passer'));
        await tester.pump(); // applique le setState (feedback = wrong)
        // Avance le Future.delayed(1000ms) qui appelle _nextCard.
        await tester.pump(const Duration(milliseconds: 1100));
      }

      // Après la dernière carte on bascule sur les résultats.
      await tester.pumpAndSettle();
      expect(find.text('Session Terminée !'), findsOneWidget);

      // On a tout passé => score 0 / 3 (rendu via un RichText -> findRichText).
      expect(find.text('0 / 3', findRichText: true), findsOneWidget);
      expect(find.text('Continuez à vous entraîner.'), findsOneWidget);
      // Boutons de fin présents.
      expect(find.text('Rejouer'), findsOneWidget);
      expect(find.text('Menu Jeu'), findsOneWidget);
    });

    testWidgets('"Rejouer" ramène à la configuration de la partie',
        (tester) async {
      seedPrefs(cards: [
        buildCard(id: 'r1', answer: 'Uno', triggers: const ['T1']),
        buildCard(id: 'r2', answer: 'Dos', triggers: const ['T2']),
      ]);
      await bootApp(tester);

      await tester.tap(find.text('Jouer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      // Passer les 2 cartes.
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Passer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1100));
      }
      await tester.pumpAndSettle();
      expect(find.text('Session Terminée !'), findsOneWidget);

      // Retour à la configuration via "Rejouer".
      await tester.tap(find.text('Rejouer'));
      await tester.pumpAndSettle();
      expect(find.text('Configuration de la Partie'), findsOneWidget);
    });
  });
}
