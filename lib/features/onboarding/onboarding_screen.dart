import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/game/game_engine.dart';
import '../../core/widgets/avatar_emblem.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/rpg_icons.dart';
import '../../data/models/enums.dart';
import '../game/game_controller.dart';
import '../quests/quest_templates.dart';
import '../legal/legal_links.dart';
import '../settings/import_flow.dart';

/// Character creation in five short steps.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _goals = [TextEditingController(), TextEditingController(), TextEditingController()];
  var _step = 0;
  var _avatar = 'sword';
  var _color = 0;
  String? _gender;
  var _class = CharacterClass.universal;
  final _focus = <AttributeType>{};
  final _templates = <int>{};
  var _busy = false;

  static const _steps = 5;

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _age.dispose();
    for (final g in _goals) {
      g.dispose();
    }
    super.dispose();
  }

  String? _validateStep() {
    if (_step == 0 && _name.text.trim().isEmpty) return 'Введите имя персонажа';
    if (_step == 1 && _age.text.trim().isNotEmpty) {
      final a = int.tryParse(_age.text.trim());
      if (a == null || a < 5 || a > 120) return 'Возраст от 5 до 120 (или оставьте пустым)';
    }
    return null;
  }

  void _next() {
    final err = _validateStep();
    if (err != null) {
      showMessage(context, err, error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    if (_step == 2 && _focus.isEmpty) _focus.addAll(_class.defaultFocus);
    if (_step == 3 && _templates.isEmpty) _preselectTemplates();
    if (_step < _steps - 1) {
      setState(() => _step++);
      _page.animateToPage(_step, duration: Durations2.medium, curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _page.animateToPage(_step, duration: Durations2.medium, curve: Curves.easeOutCubic);
  }

  void _preselectTemplates() {
    final focus = _focus.isEmpty ? AttributeType.values.toSet() : _focus;
    for (var i = 0; i < questTemplates.length && _templates.length < 3; i++) {
      final t = questTemplates[i];
      if (t.type == QuestType.daily && focus.contains(t.attribute)) _templates.add(i);
    }
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final engine = ref.read(engineProvider);
    final now = DateTime.now();
    final starters = [
      for (final i in _templates)
        questTemplates[i].build(
          engine.newId(),
          now,
          engine.config.defaultXpFor(questTemplates[i].type, questTemplates[i].difficulty),
        ),
    ];
    final draft = CharacterDraft(
      name: _name.text,
      avatarId: _avatar,
      avatarColor: _color,
      gender: _gender,
      age: int.tryParse(_age.text.trim()),
      characterClass: _class,
      focus: _focus.toList(),
      goals: _goals.map((g) => g.text).toList(),
    );
    final err = await ref
        .read(gameControllerProvider.notifier)
        .act((e, s) => e.createCharacter(s, draft, starterQuests: starters));
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showMessage(context, err, error: true);
    // Router redirects to /home once the character exists.
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
                  child: Row(
                    children: [
                      for (var i = 0; i < _steps; i++)
                        Expanded(
                          child: AnimatedContainer(
                            duration: Durations2.medium,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i <= _step ? accent : AppColors.surface3,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _stepIdentity(),
                      _stepAbout(),
                      _stepClass(),
                      _stepFocus(),
                      _stepQuests(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
                  child: Row(
                    children: [
                      if (_step > 0)
                        RpgButton(
                          label: 'Назад',
                          kind: RpgButtonKind.secondary,

                          onPressed: _busy ? null : _back,
                        ),
                      if (_step > 0) const SizedBox(width: Gap.sm),
                      Expanded(
                        child: RpgButton(
                          label: _step == _steps - 1 ? 'Начать путь' : 'Далее',

                          expand: true,
                          loading: _busy,
                          onPressed: _next,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scroll(String title, String subtitle, List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.lg),
        children: [
          Text(title, style: AppText.display(34)),
          const SizedBox(height: Gap.xs),
          Text(subtitle, style: AppText.ui(14.5, color: AppColors.textSecondary, height: 1.45)),
          const SizedBox(height: Gap.xl),
          ...children,
        ],
      );

  Widget _stepIdentity() => _scroll(
        'Создайте героя',
        'Это вы. Реальные дела будут превращаться в его опыт.',
        [
          Center(child: AvatarEmblem(avatarId: _avatar, colorIndex: _color, size: 104)),
          const SizedBox(height: Gap.sm),
          Center(
            child: TextButton(
              onPressed: () => importProgressFromFile(context, ref),
              child: const Text('Загрузить прогресс из файла'),
            ),
          ),
          const SizedBox(height: Gap.xl),
          TextField(
            controller: _name,
            maxLength: 32,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Имя персонажа', counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.lg),
          Text('ЭМБЛЕМА', style: AppText.label()),
          const SizedBox(height: Gap.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in RpgIcons.avatarKeys)
                _SelectTile(
                  selected: _avatar == k,
                  color: AppColors.avatarPalette[_color],
                  onTap: () => setState(() => _avatar = k),
                  child: Icon(RpgIcons.byKey(k),
                      color: _avatar == k ? AppColors.avatarPalette[_color] : AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Text('ЦВЕТ', style: AppText.label()),
          const SizedBox(height: Gap.xs),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < AppColors.avatarPalette.length; i++)
                Semantics(
                  button: true,
                  selected: _color == i,
                  label: 'Цвет ${i + 1}',
                  child: GestureDetector(
                    onTap: () => setState(() => _color = i),
                    child: Container(
                      width: 36,
                      height: 36,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _color == i ? AppColors.text : Colors.transparent, width: 1.2),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.avatarPalette[i]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          const LegalLinks(),
        ],
      );

  Widget _stepAbout() => _scroll(
        'Немного о вас',
        'Необязательно. Эти данные остаются приватными и не влияют на игру.',
        [
          Text('ПОЛ', style: AppText.label()),
          const SizedBox(height: Gap.xs),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final g in const ['Мужской', 'Женский', 'Другое'])
              ChoiceChipX(
                label: g,
                selected: _gender == g,
                onTap: () => setState(() => _gender = _gender == g ? null : g),
              ),
          ]),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: _age,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            decoration: const InputDecoration(labelText: 'Возраст', counterText: ''),
          ),
        ],
      );

  Widget _stepClass() => _scroll(
        'Начальный класс',
        'С чего начать. Класс задаёт стартовые приоритеты, их можно поменять в любой момент.',
        [
          for (final c in CharacterClass.values) ...[
            RpgCard(
              onTap: () => setState(() {
                _class = c;
                _focus
                  ..clear()
                  ..addAll(c.defaultFocus);
              }),
              borderColor: _class == c ? Theme.of(context).colorScheme.primary : null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.label, style: AppText.ui(16, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(c.description, style: AppText.ui(13, color: AppColors.textSecondary)),
                        if (c.defaultFocus.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Фокус: ${c.defaultFocus.map((a) => a.label.toLowerCase()).join(', ')}',
                              style: AppText.ui(12.5, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                  Radio<CharacterClass>(
                    value: c,
                    groupValue: _class,
                    onChanged: (v) => setState(() {
                      _class = c;
                      _focus
                        ..clear()
                        ..addAll(c.defaultFocus);
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ],
      );

  Widget _stepFocus() => _scroll(
        'Направления и цели',
        'Задания в выбранных направлениях дают +10% опыта.',
        [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in AttributeType.values)
                ChoiceChipX(
                  label: a.label,
                  icon: RpgIcons.attribute(a),
                  color: AppColors.attribute(a),
                  selected: _focus.contains(a),
                  onTap: () => setState(() => _focus.contains(a) ? _focus.remove(a) : _focus.add(a)),
                ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          Text('ЛИЧНЫЕ ЦЕЛИ', style: AppText.label()),
          const SizedBox(height: Gap.xs),
          for (var i = 0; i < _goals.length; i++) ...[
            TextField(
              controller: _goals[i],
              maxLength: 80,
              decoration: InputDecoration(
                hintText: const [
                  'Например: выучить английский до B2',
                  'Например: пробежать 10 км',
                  'Например: создать своё приложение',
                ][i],
                counterText: '',
                prefixIcon: const Icon(Icons.flag_outlined),
              ),
            ),
            const SizedBox(height: Gap.xs),
          ],
        ],
      );

  Widget _stepQuests() {
    final focus = _focus.isEmpty ? AttributeType.values.toSet() : _focus;
    final indices = [
      for (var i = 0; i < questTemplates.length; i++)
        if (focus.contains(questTemplates[i].attribute)) i,
      for (var i = 0; i < questTemplates.length; i++)
        if (!focus.contains(questTemplates[i].attribute)) i,
    ];
    final engine = ref.read(engineProvider);
    return _scroll(
      'Первые задания',
      'Выберите, с чего начать. Всё можно изменить позже или создать свои.',
      [
        for (final i in indices) ...[
          RpgCard(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
            onTap: () => setState(() => _templates.contains(i) ? _templates.remove(i) : _templates.add(i)),
            borderColor: _templates.contains(i) ? AppColors.attribute(questTemplates[i].attribute).o(0.6) : null,
            child: Row(
              children: [
                IconTile(RpgIcons.attribute(questTemplates[i].attribute),
                    color: AppColors.attribute(questTemplates[i].attribute), size: 36),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(questTemplates[i].title, style: AppText.ui(14.5, weight: FontWeight.w700)),
                      Text(
                        '${questTemplates[i].type.label} · '
                        '+${engine.config.defaultXpFor(questTemplates[i].type, questTemplates[i].difficulty)} XP',
                        style: AppText.ui(12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: _templates.contains(i),
                  onChanged: (_) =>
                      setState(() => _templates.contains(i) ? _templates.remove(i) : _templates.add(i)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xs),
        ],
      ],
    );
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({required this.selected, required this.color, required this.onTap, required this.child});
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.rMd,
          child: AnimatedContainer(
            duration: Durations2.fast,
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: selected ? color.o(0.14) : AppColors.surface1,
              borderRadius: Radii.rMd,
              border: Border.all(color: selected ? color.o(0.7) : AppColors.border),
            ),
            child: Center(child: child),
          ),
        ),
      );
}
