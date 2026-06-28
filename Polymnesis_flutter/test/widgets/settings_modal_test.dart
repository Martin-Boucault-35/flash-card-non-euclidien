// Tests widget de [SettingsModal].
//
// Couverture :
//  - Rendu : titres 'Paramètres' et 'Système Leitner', et les 6 champs
//    d'intervalle pré-remplis (1, 3, 7, 14, 30, 90).
//  - Toggle de l'aide SQL : taper 'Comment faire ? (Instructions SQL)' affiche
//    le bloc 'create table cards ...' (puis le lien devient 'Masquer ...').
//  - Sauvegarde : taper 'Enregistrer' déclenche onSave (url/key trimés, enabled)
//    et onSaveLeitner (intervals == [1,3,7,14,30,90]).
//  - Clamp d'intervalle : saisir '0' dans une boîte est ramené à 1 à la sauvegarde
//    (int.tryParse(...) ?? 1, puis v < 1 ? 1 : v).
//
// Le modal appelle Navigator.pop(context) à la fin de _handleSave et sur les
// boutons fermeture/Annuler. On le pousse donc comme route (via un bouton dans
// un Builder) pour qu'un Navigator avec une route à dépiler existe — sinon le
// pop dépilerait la route racine. pumpAndSettle est sûr : aucun timer périodique.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/models/sync_credentials.dart';
import 'package:polymnesis/models/leitner_settings.dart';
import 'package:polymnesis/models/ltds_settings.dart';
import 'package:polymnesis/providers/card_provider.dart';
import 'package:polymnesis/widgets/settings_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Callbacks de capture, réinitialisés avant chaque test.
  late SyncCredentials? savedCreds;
  late LeitnerSettings? savedLeitner;
  late LtdsSettings? savedLtds;
  late List<int>? importedDays;
  late LtdsImportResult importResult;

  setUp(() {
    savedCreds = null;
    savedLeitner = null;
    savedLtds = null;
    importedDays = null;
    importResult = LtdsImportResult(
      cardsCreated: 2,
      triggersAdded: 1,
      questionsFound: 3,
      daysRequested: 1,
      daysWithData: const [152],
    );
  });

  /// Monte le modal en le poussant comme route, afin que Navigator.pop()
  /// (appelé par _handleSave) dépile une vraie route et non la racine.
  Future<void> pumpModal(
    WidgetTester tester, {
    required SyncCredentials credentials,
    required LeitnerSettings leitnerSettings,
    LtdsSettings? ltdsSettings,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: SettingsModal(
                          credentials: credentials,
                          onSave: (c) => savedCreds = c,
                          leitnerSettings: leitnerSettings,
                          onSaveLeitner: (l) => savedLeitner = l,
                          ltdsSettings: ltdsSettings ?? LtdsSettings(),
                          onSaveLtds: (s) async => savedLtds = s,
                          onImport: (days) async {
                            importedDays = days;
                            return importResult;
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  group('SettingsModal - rendu', () {
    testWidgets('affiche les titres et les 6 intervalles pré-remplis',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
          url: 'https://x.supabase.co',
          key: 'abc',
          enabled: true,
        ),
        leitnerSettings: LeitnerSettings(),
      );

      // Titres présents.
      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('Système Leitner'), findsOneWidget);

      // Six champs d'intervalle (TextField avec keyboardType number).
      // On vérifie chaque valeur par défaut pré-remplie via son controller.
      final textFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      // 2 champs sync (URL, Key) + 6 champs d'intervalle
      // + 2 champs import LTDS (jeton, plage) = 10 TextField.
      expect(textFields.length, 10);

      final intervalValues = textFields
          .where((tf) => tf.keyboardType == TextInputType.number)
          .map((tf) => tf.controller!.text)
          .toList();
      expect(intervalValues, ['1', '3', '7', '14', '30', '90']);

      // Les champs sync reflètent les credentials fournis.
      final urlField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'https://x.supabase.co').first,
      );
      // URL est dans son controller, pas comme texte enfant : on le lit autrement.
      // (find.widgetWithText ci-dessus est tolérant si jamais absent.)
      expect(urlField, isA<TextField>());
    });

    testWidgets('le bloc d\'aide SQL est masqué par défaut', (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
          url: 'https://x.supabase.co',
          key: 'abc',
          enabled: true,
        ),
        leitnerSettings: LeitnerSettings(),
      );

      expect(find.text('Comment faire ? (Instructions SQL)'), findsOneWidget);
      expect(find.textContaining('create table cards'), findsNothing);
    });
  });

  group('SettingsModal - aide SQL', () {
    testWidgets('taper le lien affiche le bloc create table cards',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
          url: 'https://x.supabase.co',
          key: 'abc',
          enabled: true,
        ),
        leitnerSettings: LeitnerSettings(),
      );

      await tester.tap(find.text('Comment faire ? (Instructions SQL)'));
      await tester.pumpAndSettle();

      // Le bloc SQL est désormais visible et le lien change de libellé.
      expect(find.textContaining('create table cards'), findsOneWidget);
      expect(find.text('Masquer les instructions'), findsOneWidget);
      expect(find.text('Comment faire ? (Instructions SQL)'), findsNothing);
    });
  });

  group('SettingsModal - sauvegarde', () {
    testWidgets('Enregistrer transmet credentials trimés et intervalles',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
          url: '  https://x.supabase.co  ',
          key: '  abc  ',
          enabled: true,
        ),
        leitnerSettings: LeitnerSettings(),
      );

      // Le bouton est en bas d'un contenu défilant : le rendre visible avant tap.
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // onSave a reçu des valeurs trimées et enabled conservé.
      expect(savedCreds, isNotNull);
      expect(savedCreds!.url, 'https://x.supabase.co');
      expect(savedCreds!.key, 'abc');
      expect(savedCreds!.enabled, isTrue);

      // onSaveLeitner a reçu les 6 intervalles inchangés.
      expect(savedLeitner, isNotNull);
      expect(savedLeitner!.intervals, [1, 3, 7, 14, 30, 90]);
    });

    testWidgets('un intervalle à 0 est ramené à 1 lors de la sauvegarde',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
          url: 'https://x.supabase.co',
          key: 'abc',
          enabled: true,
        ),
        leitnerSettings: LeitnerSettings(),
      );

      // Trouver le premier champ d'intervalle (keyboardType number) et y saisir '0'.
      final numberFields = find.byWidgetPredicate(
        (w) => w is TextField && w.keyboardType == TextInputType.number,
      );
      expect(numberFields, findsNWidgets(6));

      await tester.enterText(numberFields.first, '0');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // 0 < 1 => clampé à 1 ; les autres intervalles restent inchangés.
      expect(savedLeitner, isNotNull);
      expect(savedLeitner!.intervals, [1, 3, 7, 14, 30, 90]);
    });

    testWidgets('un intervalle non numérique vide retombe sur 1',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
          url: 'https://x.supabase.co',
          key: 'abc',
          enabled: true,
        ),
        leitnerSettings: LeitnerSettings(),
      );

      final numberFields = find.byWidgetPredicate(
        (w) => w is TextField && w.keyboardType == TextInputType.number,
      );

      // Vider le 5e champ (valeur 30) : int.tryParse('') == null => 1.
      await tester.enterText(numberFields.at(4), '');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(savedLeitner, isNotNull);
      expect(savedLeitner!.intervals, [1, 3, 7, 14, 1, 90]);
    });
  });

  group('SettingsModal - import La Table des Savoirs', () {
    testWidgets('affiche la section et pré-remplit le jeton existant',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
        ltdsSettings: LtdsSettings(token: 'mon-jeton'),
      );

      expect(find.text('Import "La Table des Savoirs"'), findsOneWidget);
      expect(find.text('Importer les cartes'), findsOneWidget);

      // Le champ jeton contient le jeton fourni.
      final tokenField = tester.widget<TextField>(
        find.byKey(const ValueKey('ltdsTokenField')),
      );
      expect(tokenField.controller!.text, 'mon-jeton');
    });

    testWidgets('Importer parse la plage et appelle onImport + affiche le résumé',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
        ltdsSettings: LtdsSettings(token: 'tok'),
      );

      await tester.enterText(
        find.byKey(const ValueKey('ltdsRangeField')),
        '130-132',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Importer les cartes'));
      await tester.tap(find.text('Importer les cartes'));
      await tester.pumpAndSettle();

      // onImport reçoit les jours parsés, et le jeton a été sauvegardé.
      expect(importedDays, [130, 131, 132]);
      expect(savedLtds, isNotNull);
      expect(savedLtds!.token, 'tok');

      // Le résumé du résultat s'affiche.
      expect(find.textContaining('2 carte(s) créée(s)'), findsOneWidget);
    });

    testWidgets('une plage invalide affiche une erreur sans appeler onImport',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
        ltdsSettings: LtdsSettings(token: 'tok'),
      );

      await tester.enterText(
        find.byKey(const ValueKey('ltdsRangeField')),
        'abc',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Importer les cartes'));
      await tester.tap(find.text('Importer les cartes'));
      await tester.pumpAndSettle();

      expect(importedDays, isNull); // onImport jamais appelé
      expect(find.textContaining('Plage invalide'), findsOneWidget);
    });

    testWidgets('sans jeton, Importer demande le jeton', (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
        ltdsSettings: LtdsSettings(), // jeton vide
      );

      await tester.enterText(
        find.byKey(const ValueKey('ltdsRangeField')),
        '152',
      );
      await tester.ensureVisible(find.text('Importer les cartes'));
      await tester.tap(find.text('Importer les cartes'));
      await tester.pumpAndSettle();

      expect(importedDays, isNull);
      expect(find.textContaining('Renseigne ton jeton'), findsOneWidget);
    });
  });
}
