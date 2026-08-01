import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:polymnesis/models/models.dart';
import 'package:polymnesis/providers/card_provider.dart';

/// Clés de stockage — doivent refléter les constantes privées de [StorageService].
const String kCardsKey = 'polymnesis-cards';
const String kSyncCredsKey = 'polymnesis-sync-creds';
const String kLeitnerSettingsKey = 'polymnesis-leitner-settings';

/// Construit une [FlashCard] avec des valeurs par défaut raisonnables.
///
/// Ne surchargez que ce dont vous avez besoin. Par défaut la carte est "due"
/// (à réviser) car [nextReviewAt] vaut [createdAt] (un petit timestamp passé).
FlashCard buildCard({
  String id = 'c1',
  FlashCardTheme theme = FlashCardTheme.cultureG,
  String answer = 'Reponse',
  List<String>? triggers,
  int? createdAt,
  int leitnerBox = 1,
  int? nextReviewAt,
  List<CardEvent>? history,
}) {
  final created = createdAt ?? 1000;
  return FlashCard(
    id: id,
    theme: theme,
    answer: answer,
    triggers: triggers ?? const ['Indice 1', 'Indice 2'],
    createdAt: created,
    leitnerBox: leitnerBox,
    nextReviewAt: nextReviewAt ?? created,
    history: history ?? const [],
  );
}

/// Fabrique un [CardEvent] compact pour les tests.
CardEvent buildEvent({
  CardEventType type = CardEventType.correct,
  int fromBox = 1,
  int toBox = 2,
  int at = 1000,
}) =>
    CardEvent(type: type, fromBox: fromBox, toBox: toBox, at: at);

/// Millisecondes depuis l'époque pour `now + days` (jours peut être négatif).
///
/// Utile pour rendre une carte "due" (`daysFromNowMillis(-1)`) ou "non due"
/// (`daysFromNowMillis(5)`) dans les tests du système Leitner.
int daysFromNowMillis(int days) =>
    DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;

/// Pré-remplit le mock de SharedPreferences.
///
/// Passez [cards] pour court-circuiter le seed des [initialCards] par le
/// provider. Laissez [cards] à `null` pour tester le comportement "premier
/// lancement" (le provider sème alors les cartes par défaut).
void seedPrefs({
  List<FlashCard>? cards,
  Map<String, dynamic>? syncCreds,
  Map<String, dynamic>? leitnerSettings,
}) {
  final values = <String, Object>{};
  if (cards != null) {
    values[kCardsKey] = jsonEncode(cards.map((c) => c.toJson()).toList());
  }
  if (syncCreds != null) {
    values[kSyncCredsKey] = jsonEncode(syncCreds);
  }
  if (leitnerSettings != null) {
    values[kLeitnerSettingsKey] = jsonEncode(leitnerSettings);
  }
  SharedPreferences.setMockInitialValues(values);
}

/// Lit directement la valeur brute stockée sous [key] dans le mock prefs.
Future<String?> readRawPref(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

/// Fausse implémentation de plateforme pour flutter_local_notifications.
///
/// Sur la plateforme hôte des tests (Linux), le plugin délègue à
/// `FlutterLocalNotificationsPlatform.instance`, un champ `late` jamais
/// initialisé hors enregistrement de plugin — d'où un `LateInitializationError`.
/// On installe donc cette fausse instance (no-op) via [installFakeNotifications].
class FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
  }) async {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async =>
      <PendingNotificationRequest>[];
}

/// Installe la [FakeNotificationsPlatform] comme instance globale du plugin.
///
/// À appeler dans `setUp` de tout test dont le flux peut toucher aux
/// notifications (ex. `CardProvider.markDailyCompleted`, fin du jeu quotidien).
void installFakeNotifications() {
  FlutterLocalNotificationsPlatform.instance = FakeNotificationsPlatform();
}

/// Construit et initialise un [CardProvider] pour les tests unitaires.
///
/// Appelez [seedPrefs] avant si vous voulez un jeu de cartes connu. Sans seed,
/// le provider charge les [initialCards] (4 cartes) au premier lancement.
Future<CardProvider> makeInitializedProvider() async {
  final provider = CardProvider();
  await provider.initialize();
  return provider;
}

/// Exécute [body] en supprimant toute sortie `print`.
///
/// Utile pour les tests qui exercent volontairement un chemin d'erreur journalisé
/// via `print()` (ex. `StorageService.load*` sur du JSON corrompu) : le test reste
/// valide, mais la console n'est pas polluée par le message d'erreur attendu.
T silencePrints<T>(T Function() body) {
  return runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {/* sortie avalée volontairement */},
    ),
  );
}

/// Enveloppe [child] dans un MaterialApp + CardProvider pour les widget tests.
///
/// Si [provider] est fourni, il est réutilisé via `.value` (utile pour
/// inspecter son état après l'interaction). Sinon un provider neuf est créé.
Widget wrapWithProvider(Widget child, {CardProvider? provider}) {
  final p = provider ?? CardProvider();
  return ChangeNotifierProvider<CardProvider>.value(
    value: p,
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}
