import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service de notifications locales pour le rappel quotidien Leitner
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const int _dailyNotifId = 1;
  static const int _snoozeNotifId = 2;
  static const String _channelId = 'polymnesis_daily';
  static const String _channelName = 'Rappel quotidien';

  /// Initialise le service de notifications
  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Paris'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _initialized = true;
  }

  /// Demande la permission de notifier (Android 13+ / iOS)
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
      return granted ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Programme la notification quotidienne à 19h30
  static Future<void> scheduleDailyReminder() async {
    await _plugin.cancel(id: _dailyNotifId);

    await _plugin.zonedSchedule(
      id: _dailyNotifId,
      title: 'PolyMnesis — Révision quotidienne',
      body: 'Tu as des cartes à réviser aujourd\'hui ! 🧠',
      scheduledDate: _nextInstanceOf(19, 30),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Rappel pour faire la révision quotidienne Leitner',
          importance: Importance.high,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'snooze_30',
              'Rappel dans 30 min',
            ),
            const AndroidNotificationAction(
              'dismiss',
              'Demain',
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Programme un snooze dans 30 minutes
  static Future<void> _scheduleSnooze() async {
    final snoozeTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 30));

    await _plugin.zonedSchedule(
      id: _snoozeNotifId,
      title: 'PolyMnesis — Rappel',
      body: 'Tu as des cartes à réviser ! 🧠',
      scheduledDate: snoozeTime,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Rappel snooze Leitner',
          importance: Importance.high,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'snooze_30',
              'Rappel dans 30 min',
            ),
            const AndroidNotificationAction(
              'dismiss',
              'Demain',
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Annule la notification du jour (appelé quand les quotidiennes sont faites)
  static Future<void> cancelTodayReminder() async {
    await _plugin.cancel(id: _snoozeNotifId);
  }

  /// Annule toutes les notifications
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Callback quand l'utilisateur interagit avec la notification
  static void _onNotificationResponse(NotificationResponse response) {
    switch (response.actionId) {
      case 'snooze_30':
        _scheduleSnooze();
        break;
      case 'dismiss':
        // Ne rien faire — la notification quotidienne se relancera demain
        break;
      default:
        // Tap sur la notif elle-même — l'app s'ouvre normalement
        break;
    }
  }

  /// Calcule la prochaine occurrence de HH:MM
  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
