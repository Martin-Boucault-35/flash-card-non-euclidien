import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polymnesis/widgets/app_button.dart';

/// Tests widget de [AppButton].
///
/// Couverture :
///  - rendu de l'enfant (child) ;
///  - le tap déclenche onPressed (via InkWell / via le texte) ;
///  - bouton désactivé quand onPressed == null (le tap ne fait rien) ;
///  - état isLoading : affiche un CircularProgressIndicator et n'appelle
///    PAS onPressed au tap ;
///  - fullWidth == true => le SizedBox externe a une largeur double.infinity ;
///  - rendu (smoke) de chaque variante (primary/secondary/danger/ghost) et de
///    chaque taille (sm/md/lg) sans exception.
///
/// Aucun timer périodique ici => pumpAndSettle est utilisable sans risque.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Enveloppe un [AppButton] dans un MaterialApp minimal centré.
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('AppButton - rendu', () {
    testWidgets('affiche son enfant', (tester) async {
      await tester.pumpWidget(
        wrap(
          AppButton(
            onPressed: () {},
            child: const Text('Hi'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hi'), findsOneWidget);
    });
  });

  group('AppButton - interaction', () {
    testWidgets('le tap déclenche onPressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          AppButton(
            onPressed: () => tapped = true,
            child: const Text('Valider'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('le tap sur le texte déclenche aussi onPressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          AppButton(
            onPressed: () => tapped = true,
            child: const Text('Valider'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('désactivé quand onPressed == null (le tap ne fait rien)',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const AppButton(
            onPressed: null,
            child: Text('Inactif'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // InkWell.onTap doit être null => bouton désactivé.
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);

      // Taper ne doit rien casser (et il n'y a aucun callback à déclencher).
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.text('Inactif'), findsOneWidget);
    });
  });

  group('AppButton - isLoading', () {
    testWidgets('affiche un CircularProgressIndicator et masque le child',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          AppButton(
            onPressed: () {},
            isLoading: true,
            child: const Text('Chargement'),
          ),
        ),
      );
      // On ne settle pas : le CircularProgressIndicator anime en continu, donc
      // pumpAndSettle ne convergerait jamais.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Chargement'), findsNothing);
    });

    testWidgets('onPressed n\'est PAS appelé au tap quand isLoading',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          AppButton(
            onPressed: () => tapped = true,
            isLoading: true,
            child: const Text('Chargement'),
          ),
        ),
      );
      await tester.pump();

      // InkWell.onTap est forcé à null en chargement.
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);

      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(tapped, isFalse);
    });
  });

  group('AppButton - fullWidth', () {
    testWidgets('fullWidth == true => SizedBox externe à double.infinity',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          AppButton(
            onPressed: () {},
            fullWidth: true,
            child: const Text('Large'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Le SizedBox externe d'AppButton est le premier SizedBox descendant
      // (le CircularProgressIndicator interne n'existe pas hors isLoading).
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, double.infinity);
    });

    testWidgets('fullWidth == false => largeur non contrainte (null)',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          AppButton(
            onPressed: () {},
            child: const Text('Auto'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, isNull);
    });
  });

  group('AppButton - variantes et tailles (smoke)', () {
    testWidgets('chaque variante se rend sans exception', (tester) async {
      for (final variant in AppButtonVariant.values) {
        await tester.pumpWidget(
          wrap(
            AppButton(
              onPressed: () {},
              variant: variant,
              child: Text(variant.name),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(variant.name), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('chaque taille se rend sans exception', (tester) async {
      for (final size in AppButtonSize.values) {
        await tester.pumpWidget(
          wrap(
            AppButton(
              onPressed: () {},
              size: size,
              child: Text(size.name),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(size.name), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
