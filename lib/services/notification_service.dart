import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Numero massimo di dosi giornaliere che possiamo pianificare (intervallo minimo 1h => 24 dosi).
  // Usato anche in cancellazione per ripulire tutti gli slot possibili.
  static const int _maxDosesPerDay = 24;

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    // FIX: imposta il fuso orario locale del dispositivo.
    // Senza questo tz.local resta UTC e le notifiche scattano con ore di scarto.
    try {
      final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // Fallback: se il rilevamento fallisce restiamo su UTC (comportamento precedente).
    }

    // Configurazione Android.
    // Usiamo un'icona dedicata monocromatica in res/drawable (NON il launcher):
    // le small icon delle notifiche devono essere bianche su trasparente.
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('ic_stat_notify');

    // Configurazione iOS
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Configurazione Windows
    const WindowsInitializationSettings windowsSettings =
        WindowsInitializationSettings(
          appName: 'Richiesta Ricette',
          appUserModelId: 'com.example.richiesta_ricette',
          guid: '7a695651-d4ba-46d6-b196-afae97a489a8',
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      windows: windowsSettings,
    );

    await _notifications.initialize(settings: settings);

    // Permesso "sveglie esatte" (Android 14+)
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();

    // Permesso notifiche (Android 13+)
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'med_reminders_channel_id',
      'Promemoria Medicine',
      channelDescription: 'Notifiche per l\'assunzione dei farmaci',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
      // FONDAMENTALE: icona esplicita, così le notifiche programmate la
      // trasportano con sé e non dipendono dall'icona di default (che nel
      // BroadcastReceiver non è disponibile → causava NPE in setSmallIcon).
      icon: 'ic_stat_notify',
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Pianifica i promemoria per un farmaco.
  ///
  /// A differenza della versione precedente (che con `zonedSchedule` scattava
  /// UNA volta sola per intervalli diversi da 24h), qui distribuiamo le dosi
  /// nell'arco della giornata a partire da [startDateTime] e le facciamo
  /// ripetere OGNI GIORNO alla stessa ora tramite `DateTimeComponents.time`.
  ///
  /// Es. intervallo 8h con prima dose alle 08:00 => notifiche a 08:00, 16:00,
  /// 00:00, ripetute quotidianamente.
  static Future<void> scheduleMedicine({
    required int id,
    required String name,
    required DateTime startDateTime,
    required int intervalHours,
  }) async {
    // Ripuliamo eventuali pianificazioni precedenti per questo farmaco.
    await cancelMedicine(id);

    if (intervalHours <= 0) return;

    // Tutti gli intervalli previsti (1,4,6,8,12,24) dividono 24 esattamente.
    final int dosesPerDay = (24 ~/ intervalHours).clamp(1, _maxDosesPerDay);

    for (int i = 0; i < dosesPerDay; i++) {
      final DateTime doseTime = startDateTime.add(
        Duration(hours: intervalHours * i),
      );
      final tz.TZDateTime scheduled = _nextDailyOccurrence(
        doseTime.hour,
        doseTime.minute,
      );

      await _notifications.zonedSchedule(
        id: _doseId(id, i),
        title: 'Promemoria Farmaco',
        body: 'È ora di assumere: $name',
        scheduledDate: scheduled,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // Ripete ogni giorno alla stessa ora.
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Prossima occorrenza (oggi o domani) all'ora indicata, nel fuso locale.
  static tz.TZDateTime _nextDailyOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// ID univoco e stabile per la i-esima dose di un farmaco.
  /// Deriva sempre da [medicineId], così pianificazione e cancellazione
  /// usano gli stessi identificatori (prima erano incoerenti: id vs id.hashCode).
  static int _doseId(int medicineId, int doseIndex) =>
      (medicineId % 1000000) * 100 + doseIndex;

  /// Cancella TUTTE le dosi pianificate per un farmaco.
  static Future<void> cancelMedicine(int medicineId) async {
    for (int i = 0; i < _maxDosesPerDay; i++) {
      await _notifications.cancel(id: _doseId(medicineId, i));
    }
  }

  /// Notifica di prova, programmata a pochi secondi da adesso.
  /// Usa lo stesso meccanismo dei promemoria reali (allarme esatto), così
  /// serve a diagnosticare se il recapito funziona sul dispositivo.
  static Future<void> showTestNotification() async {
    final tz.TZDateTime when = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(seconds: 5));

    await _notifications.zonedSchedule(
      id: 999999,
      title: 'Notifica di prova',
      body: 'Se vedi questo, i promemoria funzionano correttamente.',
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
