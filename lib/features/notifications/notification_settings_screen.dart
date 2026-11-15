import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/responsive/responsive.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/states.dart';
import '../../data/models/user_settings.dart';
import '../game/game_controller.dart';
import '../settings/settings_widgets.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _set(BuildContext context, WidgetRef ref, NotificationSettings Function(NotificationSettings) f) =>
      runGameAction(context, ref, (e, s) => e.updateSettings(s, (x) => x.copyWith(notifications: f(x.notifications))));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    if (s == null) return const Scaffold(body: LoadingView());
    final n = s.settings.notifications;
    final on = n.enabled;
    final supported = NotificationService.supported;

    Widget timeRow(String title, String subtitle, bool value, String time,
            NotificationSettings Function(NotificationSettings, bool) toggle,
            NotificationSettings Function(NotificationSettings, String) setTime) =>
        ListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(
              onPressed: on && value
                  ? () async {
                      final t = await pickTime(context, time);
                      if (t != null && context.mounted) await _set(context, ref, (x) => setTime(x, t));
                    }
                  : null,
              child: Text(time, style: AppText.number(14)),
            ),
            Switch(value: value, onChanged: on ? (v) => _set(context, ref, (x) => toggle(x, v)) : null),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: AdaptiveBuilder(builder: (context, size, c) => ListView(
            padding: EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, Gap.xxl),
            children: [
              ContentWidth(
                maxWidth: 760,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!supported)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.lg),
                      child: Text(
                        'На этой платформе системные уведомления недоступны — настройки сохранятся и '
                        'заработают в мобильном приложении.',
                        style: AppText.ui(13, color: AppColors.warning),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.lg),
                      child: RpgButton(
                        label: 'Разрешить уведомления',
                        icon: Icons.notifications_active_rounded,
                        kind: RpgButtonKind.secondary,
                        onPressed: () async {
                          final ok = await ref.read(notificationServiceProvider).requestPermission();
                          if (context.mounted) {
                            showMessage(context, ok ? 'Уведомления разрешены' : 'Разрешение не выдано — его можно включить в настройках системы',
                                error: !ok);
                          }
                        },
                      ),
                    ),
                  SettingsGroup(
                    title: 'Общее',
                    footer: 'Мы не присылаем лишнего: только то, что вы включили, и не больше двух регулярных напоминаний в день.',
                    children: [
                      SwitchListTile(
                        title: const Text('Уведомления включены'),
                        value: on,
                        onChanged: (v) => _set(context, ref, (x) => x.copyWith(enabled: v)),
                      ),
                    ],
                  ),
                  SettingsGroup(title: 'Напоминания', children: [
                    timeRow('Ежедневные задания', 'Утреннее напоминание', n.dailyReminder, n.dailyReminderTime,
                        (x, v) => x.copyWith(dailyReminder: v), (x, t) => x.copyWith(dailyReminderTime: t)),
                    timeRow('Рефлексия', 'Запись в дневник в конце дня', n.reflectionReminder, n.reflectionTime,
                        (x, v) => x.copyWith(reflectionReminder: v), (x, t) => x.copyWith(reflectionTime: t)),
                    SwitchListTile(
                      title: const Text('Напоминания заданий'),
                      subtitle: const Text('Время задаётся в самом задании'),
                      value: n.questReminders,
                      onChanged: on ? (v) => _set(context, ref, (x) => x.copyWith(questReminders: v)) : null,
                    ),
                    SwitchListTile(
                      title: const Text('Дедлайны'),
                      subtitle: const Text('За день до срока, в 10:00'),
                      value: n.deadlineReminders,
                      onChanged: on ? (v) => _set(context, ref, (x) => x.copyWith(deadlineReminders: v)) : null,
                    ),
                  ]),
                  SettingsGroup(title: 'События', children: [
                    SwitchListTile(
                      title: const Text('Новый уровень'),
                      value: n.levelUp,
                      onChanged: on ? (v) => _set(context, ref, (x) => x.copyWith(levelUp: v)) : null,
                    ),
                    SwitchListTile(
                      title: const Text('Миссия завершена'),
                      value: n.missionComplete,
                      onChanged: on ? (v) => _set(context, ref, (x) => x.copyWith(missionComplete: v)) : null,
                    ),
                  ]),
                ]),
              ),
            ],
          )),
    );
  }
}
