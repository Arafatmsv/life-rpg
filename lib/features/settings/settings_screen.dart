import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/config/env.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/errors/game_exception.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/states.dart';
import '../../data/datasources/remote_game_source.dart';
import '../../data/models/user_settings.dart';
import '../authentication/session_controller.dart';
import '../game/game_controller.dart';
import 'import_flow.dart';
import 'settings_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _set(BuildContext context, WidgetRef ref, UserSettings Function(UserSettings) f) =>
      runGameAction(context, ref, (e, s) => e.updateSettings(s, f));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    if (s == null) return const Scaffold(body: LoadingView());
    final st = s.settings;
    final session = ref.watch(sessionProvider);

    String tzLabel(int? m) {
      if (m == null) return 'Как на устройстве';
      final sign = m < 0 ? '−' : '+';
      final a = m.abs();
      return 'UTC$sign${two(a ~/ 60)}:${two(a % 60)}';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: AdaptiveBuilder(builder: (context, size, c) => ListView(
            padding: EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, Gap.xxl + MediaQuery.paddingOf(context).bottom),
            children: [
              ContentWidth(
                maxWidth: 760,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SettingsGroup(
                    title: 'Игровые правила',
                    footer: 'Множитель меняет награды будущих заданий; уже полученный опыт не пересчитывается.',
                    children: [
                      ListTile(
                        title: const Text('Множитель опыта'),
                        subtitle: Slider(
                          min: 0.5,
                          max: 2.0,
                          divisions: 6,
                          value: st.xpMultiplier,
                          label: '×${st.xpMultiplier.toStringAsFixed(2)}',
                          onChanged: (v) => _set(context, ref, (x) => x.copyWith(xpMultiplier: v)),
                        ),
                        trailing: Text('×${st.xpMultiplier.toStringAsFixed(2)}', style: AppText.number(14)),
                      ),
                      ListTile(
                        title: const Text('Заданий для успешного дня'),
                        subtitle: const Text('Сколько выполнить, чтобы день засчитался в серию'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'Меньше',
                            onPressed: st.minCompletionsForStreak > 1
                                ? () => _set(context, ref, (x) => x.copyWith(minCompletionsForStreak: x.minCompletionsForStreak - 1))
                                : null,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          Text('${st.minCompletionsForStreak}', style: AppText.number(15)),
                          IconButton(
                            tooltip: 'Больше',
                            onPressed: st.minCompletionsForStreak < 20
                                ? () => _set(context, ref, (x) => x.copyWith(minCompletionsForStreak: x.minCompletionsForStreak + 1))
                                : null,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ]),
                      ),
                      ListTile(
                        leading: const Icon(Icons.gavel_rounded),
                        title: const Text('Последствия и восстановление'),
                        subtitle: Text(st.penaltiesEnabled ? 'Строгость: ${st.strictness.label}' : 'Выключены'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/profile/settings/penalties'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.notifications_rounded),
                        title: const Text('Уведомления'),
                        subtitle: Text(st.notifications.enabled ? 'Включены' : 'Выключены'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/profile/settings/notifications'),
                      ),
                    ],
                  ),
                  SettingsGroup(title: 'Оформление', children: [
                    Padding(
                      padding: const EdgeInsets.all(Gap.md),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final a in AccentTheme.values)
                          ChoiceChipX(
                            label: a.label,
                            color: AppColors.accent(a),
                            icon: Icons.circle,
                            selected: st.accent == a,
                            onTap: () => _set(context, ref, (x) => x.copyWith(accent: a)),
                          ),
                      ]),
                    ),
                    SwitchListTile(
                      title: const Text('Декоративные анимации'),
                      subtitle: const Text('Свечения, вспышки, пульсация. Выключите на слабых устройствах'),
                      value: st.animationsEnabled,
                      onChanged: (v) => _set(context, ref, (x) => x.copyWith(animationsEnabled: v)),
                    ),
                  ]),
                  SettingsGroup(
                    title: 'Время',
                    footer: 'Игровой день начинается в полночь выбранного часового пояса.',
                    children: [
                      ListTile(
                        leading: const Icon(Icons.public_rounded),
                        title: const Text('Часовой пояс'),
                        subtitle: Text(tzLabel(st.tzOffsetMinutes)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final r = await showDialog<int?>(
                            context: context,
                            builder: (ctx) => SimpleDialog(
                              title: const Text('Часовой пояс'),
                              children: [
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(ctx, -99999),
                                  child: const Text('Как на устройстве'),
                                ),
                                for (var h = -12; h <= 14; h++)
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(ctx, h * 60),
                                    child: Text(tzLabel(h * 60)),
                                  ),
                              ],
                            ),
                          );
                          if (r == null || !context.mounted) return;
                          await _set(context, ref, (x) => x.copyWith(tzOffsetMinutes: () => r == -99999 ? null : r));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.view_week_rounded),
                        title: const Text('Первый день недели'),
                        trailing: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: DateTime.monday, label: Text('Пн')),
                            ButtonSegment(value: DateTime.sunday, label: Text('Вс')),
                          ],
                          selected: {st.firstDayOfWeek},
                          showSelectedIcon: false,
                          onSelectionChanged: (v) => _set(context, ref, (x) => x.copyWith(firstDayOfWeek: v.first)),
                        ),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: 'Данные',
                    footer: 'Экспорт и импорт переносят прогресс между устройствами и версиями приложения '
                        '(например, из веб-версии в приложение для iPhone).',
                    children: [
                    ListTile(
                      leading: const Icon(Icons.download_rounded),
                      title: const Text('Экспорт данных'),
                      subtitle: const Text('Все задания, опыт, дневник и настройки в JSON'),
                      onTap: () async {
                        try {
                          await ref.read(exportServiceProvider).share(s);
                        } catch (e) {
                          if (context.mounted) showMessage(context, 'Не удалось экспортировать: $e', error: true);
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.upload_file_rounded),
                      title: const Text('Импорт данных'),
                      subtitle: const Text('Загрузить прогресс из файла экспорта'),
                      onTap: () => importProgressFromFile(context, ref),
                    ),
                  ]),
                  SettingsGroup(
                    title: 'Аккаунт',
                    footer: session.isUser
                        ? 'Данные синхронизируются между устройствами через ваш аккаунт.'
                        : 'В гостевом режиме прогресс хранится только на этом устройстве.',
                    children: [
                      if (session.isUser) ...[
                        ListTile(
                          leading: const Icon(Icons.alternate_email_rounded),
                          title: Text(session.email ?? 'Аккаунт'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout_rounded),
                          title: const Text('Выйти'),
                          onTap: () async {
                            final pending = ref.read(syncStatusProvider).pending;
                            final ok = await confirm(context,
                                title: 'Выйти из аккаунта?',
                                message: pending > 0
                                    ? 'Ещё $pending изменений не отправлены на сервер. Они останутся на устройстве '
                                        'и отправятся при следующем входе.'
                                    : 'Прогресс сохранён в облаке.',
                                confirmLabel: 'Выйти');
                            if (ok) await ref.read(sessionProvider.notifier).signOut();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.person_remove_rounded, color: AppColors.danger),
                          title: Text('Удалить аккаунт',
                              style: AppText.ui(15, weight: FontWeight.w600, color: AppColors.danger)),
                          subtitle: const Text('Безвозвратно удаляет все данные на сервере и устройстве'),
                          onTap: () => _deleteAccount(context, ref),
                        ),
                      ] else ...[
                        if (Env.hasSupabase)
                          ListTile(
                            leading: const Icon(Icons.cloud_upload_rounded),
                            title: const Text('Войти или создать аккаунт'),
                            subtitle: const Text('Текущий прогресс перенесётся в новый аккаунт'),
                            onTap: () => ref.read(sessionProvider.notifier).leaveGuest(),
                          ),
                        ListTile(
                          leading: const Icon(Icons.restart_alt_rounded, color: AppColors.danger),
                          title: Text('Начать заново',
                              style: AppText.ui(15, weight: FontWeight.w600, color: AppColors.danger)),
                          subtitle: const Text('Удалить персонажа и весь прогресс с устройства'),
                          onTap: () async {
                            final ok = await _typedConfirm(context,
                                'Весь прогресс на этом устройстве будет удалён без возможности восстановления.');
                            if (ok) await ref.read(gameControllerProvider.notifier).wipeLocal();
                          },
                        ),
                      ],
                    ],
                  ),
                  SettingsGroup(title: 'Документы', children: [
                    ListTile(
                      title: const Text('Как устроена игра'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/profile/help'),
                    ),
                    ListTile(
                      title: const Text('Условия использования'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/legal/terms'),
                    ),
                    ListTile(
                      title: const Text('Политика конфиденциальности'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/legal/privacy'),
                    ),
                  ]),
                  Center(
                    child: Text('Life RPG 0.1.0', style: AppText.ui(12, color: AppColors.textMuted)),
                  ),
                ]),
              ),
            ],
          )),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await _typedConfirm(context,
        'Аккаунт, персонаж, задания, дневник и вся история будут удалены с сервера и устройства. '
        'Это нельзя отменить. Перед удалением можно сделать экспорт данных.');
    if (!ok || !context.mounted) return;
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    try {
      await RemoteGameSource(client).deleteAccount();
      await ref.read(gameControllerProvider.notifier).wipeLocal();
      await ref.read(sessionProvider.notifier).signOut();
    } catch (e) {
      if (context.mounted) {
        showMessage(context, 'Не удалось удалить аккаунт: ${describeError(e)}. Проверьте интернет.', error: true);
      }
    }
  }

  static Future<bool> _typedConfirm(BuildContext context, String message) async {
    final ctrl = TextEditingController();
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Вы уверены?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message),
            const SizedBox(height: Gap.md),
            Text('Введите УДАЛИТЬ для подтверждения', style: AppText.ui(12.5, color: AppColors.textMuted)),
            const SizedBox(height: Gap.xs),
            TextField(controller: ctrl, autofocus: true, onChanged: (_) => setState(() {})),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            RpgButton(
              label: 'Удалить',
              compact: true,
              kind: RpgButtonKind.danger,
              onPressed: ctrl.text.trim().toUpperCase() == 'УДАЛИТЬ' ? () => Navigator.pop(ctx, true) : null,
            ),
          ],
        ),
      ),
    );
    return r ?? false;
  }
}
