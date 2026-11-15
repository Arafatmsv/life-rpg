import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/widgets/avatar_emblem.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/rpg_icons.dart';
import '../../data/models/enums.dart';
import '../game/game_controller.dart';

Future<void> openCharacterEditor(BuildContext context) =>
    showRpgSheet(context, builder: (_) => const CharacterEditSheet());

/// Name, avatar, class, development priorities and goals.
class CharacterEditSheet extends ConsumerStatefulWidget {
  const CharacterEditSheet({super.key});

  @override
  ConsumerState<CharacterEditSheet> createState() => _CharacterEditSheetState();
}

class _CharacterEditSheetState extends ConsumerState<CharacterEditSheet> {
  late final ch = ref.read(gameControllerProvider).valueOrNull!.character!;
  late final _name = TextEditingController(text: ch.name);
  late final _goals = [
    for (var i = 0; i < 3; i++) TextEditingController(text: i < ch.goals.length ? ch.goals[i] : ''),
  ];
  late var _avatar = ch.avatarId;
  late var _color = ch.avatarColor;
  late var _class = ch.characterClass;
  late final _focus = {...ch.focus};
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    for (final g in _goals) {
      g.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await runGameAction(
      context,
      ref,
      (e, s) => e.updateCharacter(
        s,
        (c) => c.copyWith(
          name: _name.text.trim(),
          avatarId: _avatar,
          avatarColor: _color,
          characterClass: _class,
          focus: _focus.toList(),
          goals: _goals.map((g) => g.text.trim()).where((g) => g.isNotEmpty).toList(),
        ),
      ),
      success: 'Персонаж обновлён',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(snapshotProvider)?.level.level ?? 1;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
        children: [
          Text('Персонаж', style: AppText.display(28)),
          const SizedBox(height: Gap.md),
          Center(child: AvatarEmblem(avatarId: _avatar, colorIndex: _color, level: level, size: 100)),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _name,
            maxLength: 32,
            decoration: const InputDecoration(labelText: 'Имя', counterText: ''),
          ),
          const SizedBox(height: Gap.md),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in RpgIcons.avatarKeys)
              IconButton(
                tooltip: 'Эмблема',
                isSelected: _avatar == k,
                style: IconButton.styleFrom(
                  backgroundColor: _avatar == k ? AppColors.avatarPalette[_color].o(0.16) : AppColors.surface1,
                  side: BorderSide(color: _avatar == k ? AppColors.avatarPalette[_color] : AppColors.border),
                ),
                onPressed: () => setState(() => _avatar = k),
                icon: Icon(RpgIcons.byKey(k),
                    color: _avatar == k ? AppColors.avatarPalette[_color] : AppColors.textSecondary),
              ),
          ]),
          const SizedBox(height: Gap.sm),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < AppColors.avatarPalette.length; i++)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _color = i),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.avatarPalette[i],
                    border: Border.all(color: _color == i ? AppColors.text : Colors.transparent, width: 2.5),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: Gap.lg),
          Text('КЛАСС', style: AppText.label()),
          const SizedBox(height: Gap.xs),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in CharacterClass.values)
              ChoiceChipX(
                label: c.label,
                icon: RpgIcons.characterClass(c),
                selected: _class == c,
                onTap: () => setState(() => _class = c),
              ),
          ]),
          const SizedBox(height: Gap.lg),
          Text('ПРИОРИТЕТЫ РАЗВИТИЯ (+10% XP)', style: AppText.label()),
          const SizedBox(height: Gap.xs),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in AttributeType.values)
              ChoiceChipX(
                label: a.label,
                icon: RpgIcons.attribute(a),
                color: AppColors.attribute(a),
                selected: _focus.contains(a),
                onTap: () => setState(() => _focus.contains(a) ? _focus.remove(a) : _focus.add(a)),
              ),
          ]),
          const SizedBox(height: Gap.lg),
          Text('ЛИЧНЫЕ ЦЕЛИ', style: AppText.label()),
          const SizedBox(height: Gap.xs),
          for (final g in _goals) ...[
            TextField(
              controller: g,
              maxLength: 80,
              decoration: const InputDecoration(counterText: '', prefixIcon: Icon(Icons.flag_outlined)),
            ),
            const SizedBox(height: Gap.xs),
          ],
          const SizedBox(height: Gap.lg),
          RpgButton(label: 'Сохранить', icon: Icons.check_rounded, expand: true, loading: _busy, onPressed: _save),
        ],
      ),
    );
  }
}
