import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/enums.dart';
import '../../data/models/game_state.dart';
import '../../data/models/quest.dart';
import '../utils/day.dart';

/// Local notifications. All schedules are rebuilt from the game state, so
/// they never drift from what the player configured. No-op on web.
class NotificationService {
  NotificationService();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _lastSignature;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static const _channel = AndroidNotificationDetails(
    'life_rpg_reminders',
    'Напоминания',
    channelDescription: 'Напоминания о заданиях и рефлексии',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  static const _events = AndroidNotificationDetails(
    'life_rpg_events',
    'Игровые события',
    channelDescription: 'Новый уровень, завершённые миссии',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _details = NotificationDetails(
    android: _channel,
    iOS: DarwinNotificationDetails(),
  );
  static const _eventDetails = NotificationDetails(
    android: _events,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (!supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    _ready = true;
  }

  /// Asks the OS for permission. Returns whether notifications are allowed.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final a = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await a?.requestNotificationsPermission() ?? false;
    }
    final i = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await i?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  Future<void> showEvent(String title, String body) async {
    if (!supported) return;
    await init();
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000 + 900000,
      title,
      body,
      _eventDetails,
    );
  }

  /// Rebuilds all scheduled reminders. Cheap to call: skips work when the
  /// relevant part of the state did not change.
  Future<void> reschedule(GameState s) async {
    if (!supported) return;
    final n = s.settings.notifications;
    final quests = s.liveQuests
        .where((q) => q.isOpen && (q.reminderTime != null || q.dueDay != null))
        .toList();
    final signature = [
      n.toJson().toString(),
      for (final q in quests) '${q.id}|${q.reminderTime}|${q.dueDay}|${q.status.name}|${q.recurrence.toJson()}',
    ].join(';');
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    await init();
    await _plugin.cancelAll();
    if (!n.enabled) return;

    var budget = 60; // iOS keeps at most 64 pending notifications
    if (n.dailyReminder) {
      await _daily(1, n.dailyReminderTime, 'Новый день — новые задания',
          'Загляните в журнал заданий: опыт ждёт.');
      budget--;
    }
    if (n.reflectionReminder) {
      await _daily(2, n.reflectionTime, 'Время рефлексии',
          'Запишите, что получилось сегодня и чему вы научились.');
      budget--;
    }
    final today = dayKeyOf(DateTime.now());
    for (final q in quests) {
      if (budget <= 0) break;
      final base = 1000 + (q.id.hashCode & 0x3fffff) * 8;
      if (n.questReminders && q.reminderTime != null) {
        if (q.periodKind == PeriodKind.day &&
            (q.recurrence.kind == RecurrenceKind.daily ||
                q.recurrence.kind == RecurrenceKind.none)) {
          await _daily(base, q.reminderTime!, q.title, 'Ежедневное задание · ${q.attribute.label}');
          budget--;
        } else if (q.periodKind == PeriodKind.day) {
          // Weekday / interval schedules: the next 7 scheduled occurrences.
          var k = 0;
          for (var i = 0; i < 14 && k < 7 && budget > 0; i++) {
            final day = addDays(today, i);
            if (!q.recurrence.isScheduledOn(day, q.startDay)) continue;
            if (await _once(base + 1 + k, day, q.reminderTime!, q.title,
                'Запланировано на сегодня · ${q.attribute.label}')) {
              budget--;
            }
            k++;
          }
        } else if (q.dueDay != null) {
          if (await _once(base, q.dueDay!, q.reminderTime!, q.title, 'Напоминание о задании')) {
            budget--;
          }
        }
      }
      if (n.deadlineReminders && q.dueDay != null && q.periodKind == PeriodKind.once) {
        final dayBefore = addDays(q.dueDay!, -1);
        if (await _once(base + 7, dayBefore, '10:00', 'Дедлайн завтра: ${q.title}',
            'Остался один день — ещё можно успеть.')) {
          budget--;
        }
      }
    }
  }

  (int, int) _parse(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p.first) ?? 9, int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  Future<void> _daily(int id, String time, String title, String body) async {
    final (h, m) = _parse(time);
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      at,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<bool> _once(int id, String day, String time, String title, String body) async {
    final (h, m) = _parse(time);
    final d = parseDayKey(day);
    final at = tz.TZDateTime(tz.local, d.year, d.month, d.day, h, m);
    if (!at.isAfter(tz.TZDateTime.now(tz.local))) return false;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      at,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }
}
