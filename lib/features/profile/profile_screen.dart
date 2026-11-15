import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/config/env.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/game/achievement_catalog.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/avatar_emblem.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/states.dart';
import '../../data/repositories/sync_service.dart';
import '../authentication/session_controller.dart';
import '../game/game_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    final snap = ref.watch(snapshotProvider);
    final session = ref.watch(sessionProvider);
    final sync = ref.watch(syncStatusProvider);
    if (s == null || snap == null) return const Scaffold(body: LoadingView());
    final ch = s.character!;
    final openPenalties = s.penalties.values.where((p) => !p.status.isResolved).length;
    final journalToday = s.journal.values.any((j) => j.dayKey == snap.today && !j.deleted && !j.isEmpty);

    final account = RpgCard(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AvatarEmblem(avatarId: ch.avatarId, colorIndex: ch.avatarColor, level: snap.level.level, size: 72),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ch.name, style: AppText.display(26)),
              Text(
                session.isUser ? (session.email ?? 'Аккаунт') : 'Гостевой режим · данные на устройстве',
                style: AppText.ui(13, color: AppColors.textSecondary),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: Gap.md),
        Container(
          padding: const EdgeInsets.all(Gap.sm),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: Radii.rMd,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(children: [
            Icon(
              switch (sync.phase) {
                SyncPhase.localOnly => Icons.phone_android_rounded,
                SyncPhase.idle => Icons.cloud_done_rounded,
                SyncPhase.syncing => Icons.cloud_sync_rounded,
                SyncPhase.offline => Icons.cloud_off_rounded,
                SyncPhase.error => Icons.sync_problem_rounded,
              },
              color: switch (sync.phase) {
                SyncPhase.idle => AppColors.textSecondary,
                SyncPhase.offline => AppColors.warning,
                SyncPhase.error => AppColors.danger,
                _ => AppColors.textSecondary,
              },
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sync.phase.label, style: AppText.ui(13.5, weight: FontWeight.w700)),
                Text(
                  [
                    if (sync.pending > 0) 'в очереди: ${sync.pending}',
                    if (sync.rejected > 0) 'отклонено сервером: ${sync.rejected}',
                    if (sync.lastSyncedAt != null)
                      'последняя: ${two(sync.lastSyncedAt!.hour)}:${two(sync.lastSyncedAt!.minute)}',
                    if (sync.phase == SyncPhase.localOnly)
                      Env.hasSupabase ? 'войдите в аккаунт для синхронизации' : 'облако не настроено в этой сборке',
                  ].join(' · '),
                  style: AppText.ui(12, color: AppColors.textMuted),
                ),
              ]),
            ),
            if (session.isUser)
              IconButton(
                tooltip: 'Синхронизировать сейчас',
                onPressed: () => ref.read(gameControllerProvider.notifier).syncNow(forcePull: true),
                icon: const Icon(Icons.sync_rounded),
              ),
          ]),
        ),
      ]),
    );

    final items = <_MenuItem>[
      _MenuItem(Icons.insights_rounded, 'Аналитика', 'Графики опыта и активности', '/profile/analytics', AppColors.info),
      _MenuItem(Icons.emoji_events_rounded, 'Достижения',
          '${s.achievements.length} из ${achievementCatalog.length}', '/profile/achievements', AppColors.gold),
      _MenuItem(Icons.storefront_rounded, 'Магазин наград', '${snap.gold} Gold на счету', '/profile/rewards',
          AppColors.gold),
      _MenuItem(Icons.menu_book_rounded, 'Дневник',
          journalToday ? 'Запись за сегодня есть' : 'Как прошёл сегодняшний день?', '/profile/journal',
          AppColors.violetBright),
      _MenuItem(Icons.local_fire_department_rounded, 'Серии и отдых',
          'Серия ${snap.streak.current} · рекорд ${snap.streak.longest}', '/profile/streaks', AppColors.warning),
      _MenuItem(Icons.healing_rounded, 'Журнал последствий',
          openPenalties == 0 ? 'Открытых нарушений нет' : 'Открыто: $openPenalties', '/profile/penalties',
          openPenalties == 0 ? AppColors.success : AppColors.warning),
      _MenuItem(Icons.tune_rounded, 'Настройки', 'Игровые правила, уведомления, аккаунт', '/profile/settings',
          AppColors.textSecondary),
      _MenuItem(Icons.help_outline_rounded, 'Как устроена игра', 'Опыт, Gold, очки навыков, серии и остальное',
          '/profile/help', AppColors.textSecondary),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: AdaptiveBuilder(builder: (context, size, c) => ListView(
            padding: EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, Gap.xxl + MediaQuery.paddingOf(context).bottom),
            children: [
              ContentWidth(
                maxWidth: 980,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  account,
                  const SizedBox(height: Gap.md),
                  RpgCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (var k = 0; k < items.length; k++) ...[
                        if (k > 0) const Divider(height: 1, indent: Gap.md),
                        InkWell(
                          onTap: () => context.push(items[k].route),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 14),
                            child: Row(children: [
                              IconTile(items[k].icon, color: AppColors.textSecondary, size: 36),
                              const SizedBox(width: Gap.md),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(items[k].title, style: AppText.ui(15, weight: FontWeight.w500)),
                                  const SizedBox(height: 2),
                                  Text(items[k].subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.ui(12.5, color: AppColors.textMuted)),
                                ]),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                            ]),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ]),
              ),
            ],
          )),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.title, this.subtitle, this.route, this.color);
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color color;
}
