import 'package:flutter_test/flutter_test.dart';
import 'package:polymnesis/services/notification_service.dart';

import '../helpers/test_helpers.dart';

/// Tests du [NotificationService] (rappel quotidien Leitner).
///
/// Couverture honnête et déterministe :
///  - [NotificationService.cancelAll] se termine sans lever.
///  - [NotificationService.cancelTodayReminder] se termine sans lever.
///  - [NotificationService.requestPermission] renvoie un bool (sur l'hôte
///    Linux, les branches Android/iOS sont nulles → retourne `true`).
///
/// Note : [NotificationService.initialize] et
/// [NotificationService.scheduleDailyReminder] reposent sur des canaux de
/// plateforme et la timezone (`tz.zonedSchedule`) ; elles sont validées en
/// intégration, pas ici. On n'appelle donc PAS `scheduleDailyReminder`.
/// La [FakeNotificationsPlatform] (no-op) est installée dans [setUp] pour
/// éviter le `LateInitializationError` du plugin sur la plateforme hôte.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    installFakeNotifications();
  });

  group('NotificationService - annulation', () {
    test('cancelAll se termine sans lever d\'exception', () async {
      await expectLater(NotificationService.cancelAll(), completes);
    });

    test('cancelTodayReminder se termine sans lever d\'exception', () async {
      await expectLater(NotificationService.cancelTodayReminder(), completes);
    });

    test('cancelAll est idempotent (appels répétés sans erreur)', () async {
      await NotificationService.cancelAll();
      await NotificationService.cancelAll();
      // Aucune exception attendue lors d'appels successifs.
    });
  });

  group('NotificationService - permission', () {
    test('requestPermission renvoie un booléen', () async {
      final granted = await NotificationService.requestPermission();
      expect(granted, isA<bool>());
    });

    test('requestPermission renvoie true sur l\'hôte (pas d\'Android/iOS)',
        () async {
      // Les branches Android et iOS résolvent à null hors plateforme mobile,
      // le service retombe alors sur `return true`.
      final granted = await NotificationService.requestPermission();
      expect(granted, isTrue);
    });
  });
}
