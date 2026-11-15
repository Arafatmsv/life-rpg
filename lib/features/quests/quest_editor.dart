import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/rpg_icons.dart';
import '../../data/models/enums.dart';
import '../../data/models/quest.dart';
import '../game/game_controller.dart';
import 'quest_templates.dart';

/// Opens the quest editor. Pass [quest] to edit an existing one.
Future<void> openQuestEditor(BuildContext context, {Quest? quest, QuestType? type}) =>
    showRpgSheet(context, builder: (_) => QuestEditor(quest: quest, initialType: type));

class QuestEditor extends ConsumerStatefulWidget {
  const QuestEditor({super.key, this.quest, this.initialType});
  final Quest? quest;
  final QuestType? initialType;

  @override
  ConsumerState<QuestEditor> createState() => _QuestEditorState();
}

class _QuestEditorState extends ConsumerState<QuestEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.quest?.title ?? '');
  late final _desc = TextEditingController(text: widget.quest?.description ?? '');
  late final _target = TextEditingController(
      text: (widget.quest?.targetAmount ?? 1) > 1 ? '${widget.quest!.targetAmount}' : '');
  late final _duration = TextEditingController(text: widget.quest?.durationMinutes?.toString() ?? '');
  late final _subtask = TextEditingController();
  final _subtaskFocus = FocusNode();

  late QuestType _type = widget.quest?.type ?? widget.initialType ?? QuestType.daily;
  late AttributeType _attr = widget.quest?.attribute ??
      (ref.read(gameControllerProvider).valueOrNull?.character?.focus.firstOrNull ??
          AttributeType.discipline);
  late Difficulty _difficulty = widget.quest?.difficulty ?? Difficulty.normal;
  late bool _customXp = widget.quest?.customXp ?? false;
  late int _xp = widget.quest?.xpReward ?? 20;
  late RecurrenceKind _recKind = widget.quest?.recurrence.kind ?? RecurrenceKind.daily;
  late Set<int> _weekdays = {...?widget.quest?.recurrence.weekdays};
  late int _interval = widget.quest?.recurrence.interval ?? 2;
  late MetricUnit _unit = widget.quest?.unit ?? MetricUnit.none;
  late String _start = widget.quest?.startDay ?? dayKeyOf(DateTime.now());
  late String? _due = widget.quest?.dueDay;
  late String? _reminder = widget.quest?.reminderTime;
  late List<Subtask> _subtasks = [...?widget.quest?.subtasks];
  var _busy = false;

  bool get _isNew => widget.quest == null;

  @override
  void dispose() {
    for (final c in [_title, _desc, _target, _duration, _subtask]) {
      c.dispose();
    }
    _subtaskFocus.dispose();
    super.dispose();
  }

  void _applyTemplate(QuestTemplate t) => setState(() {
        _title.text = t.title;
        _type = t.type;
        _attr = t.attribute;
        _difficulty = t.difficulty;
        _unit = t.unit;
        _target.text = t.target > 1 ? '${t.target}' : '';
        _duration.text = t.minutes?.toString() ?? '';
        _recKind = t.type == QuestType.daily ? RecurrenceKind.daily : RecurrenceKind.weekly;
      });

  Future<void> _pickDate(bool due) async {
    final initial = parseDayKey(due ? (_due ?? dayKeyOf(DateTime.now())) : _start);
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime.now().subtract(Duration(days: due ? 0 : 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d == null) return;
    setState(() => due ? _due = dayKeyOf(d) : _start = dayKeyOf(d));
  }

  Future<void> _pickTime() async {
    final p = (_reminder ?? '09:00').split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
    );
    if (t == null) return;
    setState(() => _reminder = '${two(t.hour)}:${two(t.minute)}');
  }

  void _addSubtask() {
    final t = _subtask.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _subtasks = [..._subtasks, Subtask(id: ref.read(engineProvider).newId(), title: t)];
      _subtask.clear();
    });
    // Keep typing the next subtask without tapping the field again.
    _subtaskFocus.requestFocus();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final engine = ref.read(engineProvider);
    final now = DateTime.now();
    final target = int.tryParse(_target.text.trim()) ?? 1;
    final base = widget.quest ??
        Quest(
          id: engine.newId(),
          title: '',
          type: _type,
          attribute: _attr,
          difficulty: _difficulty,
          xpReward: 0,
          startDay: _start,
          createdAt: now,
          updatedAt: now,
        );
    final q = base.copyWith(
      title: _title.text,
      description: _desc.text,
      type: _type,
      attribute: _attr,
      difficulty: _difficulty,
      xpReward: _xp,
      customXp: _customXp,
      recurrence: Recurrence(kind: _recKind, weekdays: _weekdays, interval: _interval),
      startDay: _start,
      dueDay: () => _type.isMission || _type == QuestType.side ? _due : null,
      durationMinutes: () => int.tryParse(_duration.text.trim()),
      reminderTime: () => _reminder,
      targetAmount: _type == QuestType.main ? 1 : target.clamp(1, 1000000),
      unit: _type == QuestType.boss || _type == QuestType.main ? MetricUnit.none : _unit,
      subtasks: _type == QuestType.main ? _subtasks : const [],
    );
    final ok = await runGameAction(context, ref, (e, s) => e.saveQuest(s, q),
        success: _isNew ? 'Задание создано' : 'Изменения сохранены');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(engineProvider).config;
    final minXp = cfg.minCustomXp(_type, _difficulty), maxXp = cfg.maxCustomXp(_type, _difficulty);
    final defXp = cfg.defaultXpFor(_type, _difficulty);
    if (!_customXp) _xp = defXp;
    _xp = _xp.clamp(minXp, maxXp);
    final once = _type == QuestType.main || _type == QuestType.side || _type == QuestType.boss;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scroll) => Form(
        key: _form,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
          children: [
            Text(_isNew ? 'Новое задание' : 'Редактирование', style: AppText.display(28)),
            const SizedBox(height: Gap.md),
            if (_isNew) ...[
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: questTemplates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ActionChip(
                    avatar: Icon(RpgIcons.attribute(questTemplates[i].attribute),
                        size: 16, color: AppColors.attribute(questTemplates[i].attribute)),
                    label: Text(questTemplates[i].title),
                    onPressed: () => _applyTemplate(questTemplates[i]),
                  ),
                ),
              ),
              const SizedBox(height: Gap.md),
            ],
            TextFormField(
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Название', counterText: ''),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Введите название' : null,
            ),
            const SizedBox(height: Gap.sm),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              minLines: 1,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Описание (необязательно)', counterText: ''),
            ),
            _label('ТИП'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in QuestType.values)
                ChoiceChipX(
                  label: t.label,
                  icon: RpgIcons.questType(t),
                  color: AppColors.questType(t),
                  selected: _type == t,
                  onTap: widget.quest != null && widget.quest!.type.isMission != t.isMission
                      ? () => showMessage(context, 'Тип миссии нельзя сменить на обычный и наоборот', error: true)
                      : () => setState(() {
                            _type = t;
                            if (t == QuestType.daily && _recKind == RecurrenceKind.weekly) {
                              _recKind = RecurrenceKind.daily;
                            }
                            if (t == QuestType.boss && (int.tryParse(_target.text) ?? 0) < 2) {
                              _target.text = '30';
                            }
                          }),
                ),
            ]),
            _label('ХАРАКТЕРИСТИКА'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in AttributeType.values)
                ChoiceChipX(
                  label: a.label,
                  icon: RpgIcons.attribute(a),
                  color: AppColors.attribute(a),
                  selected: _attr == a,
                  onTap: () => setState(() => _attr = a),
                ),
            ]),
            _label('СЛОЖНОСТЬ'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in Difficulty.values)
                ChoiceChipX(
                  label: '${d.label} · ${cfg.defaultXpFor(_type, d)}',
                  color: AppColors.difficulty(d),
                  selected: _difficulty == d,
                  onTap: () => setState(() => _difficulty = d),
                ),
            ]),
            const SizedBox(height: Gap.sm),
            RpgCard(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Своя награда XP'),
                    subtitle: Text('В пределах $minXp–$maxXp для этой сложности'),
                    value: _customXp,
                    onChanged: (v) => setState(() => _customXp = v),
                  ),
                  if (_customXp)
                    Row(children: [
                      Expanded(
                        child: Slider(
                          min: minXp.toDouble(),
                          max: maxXp.toDouble(),
                          divisions: (maxXp - minXp).clamp(1, 200),
                          value: _xp.toDouble(),
                          label: '$_xp XP',
                          onChanged: (v) => setState(() => _xp = v.round()),
                        ),
                      ),
                      Text('$_xp XP', style: AppText.number(14, color: AppColors.violetBright)),
                    ]),
                ],
              ),
            ),
            if (_type == QuestType.daily) ...[
              _label('ПОВТОРЕНИЕ'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in const [RecurrenceKind.daily, RecurrenceKind.weekdays, RecurrenceKind.interval])
                  ChoiceChipX(label: k.label, selected: _recKind == k, onTap: () => setState(() => _recKind = k)),
              ]),
              if (_recKind == RecurrenceKind.weekdays) ...[
                const SizedBox(height: Gap.sm),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (var d = 1; d <= 7; d++)
                    ChoiceChipX(
                      label: weekdayShort[d - 1],
                      selected: _weekdays.contains(d),
                      onTap: () => setState(() {
                        _weekdays = {..._weekdays};
                        _weekdays.contains(d) ? _weekdays.remove(d) : _weekdays.add(d);
                      }),
                    ),
                ]),
              ],
              if (_recKind == RecurrenceKind.interval) ...[
                const SizedBox(height: Gap.sm),
                Row(children: [
                  Text('Каждые', style: AppText.ui(14)),
                  IconButton(
                    tooltip: 'Меньше',
                    onPressed: _interval > 2 ? () => setState(() => _interval--) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text('$_interval', style: AppText.number(16)),
                  IconButton(
                    tooltip: 'Больше',
                    onPressed: _interval < 30 ? () => setState(() => _interval++) : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                  Text(plural(_interval, 'день', 'дня', 'дней'), style: AppText.ui(14)),
                ]),
              ],
            ],
            if (_type == QuestType.boss) ...[
              _label('ДЛИТЕЛЬНОСТЬ ИСПЫТАНИЯ'),
              TextFormField(
                controller: _target,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Сколько дней-отметок нужно',
                  helperText: 'Одна отметка в день. Например, 30 дней английского',
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim()) ?? 0;
                  return n < 2 || n > 365 ? 'От 2 до 365 дней' : null;
                },
              ),
            ],
            if (_type == QuestType.daily || _type == QuestType.weekly || _type == QuestType.side) ...[
              _label('ИЗМЕРИМАЯ ЦЕЛЬ (НЕОБЯЗАТЕЛЬНО)'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _target,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Цель', hintText: 'напр. 5000'),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        final n = int.tryParse(t) ?? 0;
                        if (n < 1 || n > 1000000) return 'От 1 до 1 000 000';
                        if (n > 1 && _unit == MetricUnit.none) return 'Выберите единицу';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: DropdownButtonFormField<MetricUnit>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: 'Единица'),
                      items: [
                        for (final u in MetricUnit.values)
                          DropdownMenuItem(value: u, child: Text(u == MetricUnit.none ? '—' : u.label)),
                      ],
                      onChanged: (u) => setState(() => _unit = u ?? MetricUnit.none),
                    ),
                  ),
                ],
              ),
            ],
            if (_type == QuestType.main) ...[
              _label('ПОДЗАДАЧИ'),
              for (final st in _subtasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(st.done ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 18, color: st.done ? AppColors.success : AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(st.title, style: AppText.ui(14))),
                    IconButton(
                      tooltip: 'Удалить подзадачу',
                      onPressed: () => setState(() => _subtasks = _subtasks.where((x) => x.id != st.id).toList()),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ]),
                ),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _subtask,
                    focusNode: _subtaskFocus,
                    textInputAction: TextInputAction.done,
                    maxLength: 120,
                    decoration: const InputDecoration(hintText: 'Новая подзадача', counterText: ''),
                    onSubmitted: (_) => _addSubtask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Добавить подзадачу',
                  onPressed: _addSubtask,
                  icon: const Icon(Icons.add_rounded),
                ),
              ]),
            ],
            _label('СРОКИ И НАПОМИНАНИЯ'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _DateButton(
                icon: Icons.play_arrow_rounded,
                label: 'Начало: ${humanDay(_start)}',
                onTap: () => _pickDate(false),
              ),
              if (once)
                _DateButton(
                  icon: Icons.event_rounded,
                  label: _due == null ? 'Без дедлайна' : 'Дедлайн: ${humanDayYear(_due!)}',
                  onTap: () => _pickDate(true),
                  onClear: _due == null ? null : () => setState(() => _due = null),
                ),
              _DateButton(
                icon: Icons.notifications_active_outlined,
                label: _reminder == null ? 'Без напоминания' : 'Напомнить в $_reminder',
                onTap: _pickTime,
                onClear: _reminder == null ? null : () => setState(() => _reminder = null),
              ),
            ]),
            const SizedBox(height: Gap.sm),
            TextFormField(
              controller: _duration,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Продолжительность, мин (необязательно)',
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = int.tryParse(t) ?? 0;
                return n < 1 || n > 1440 ? 'От 1 до 1440 минут' : null;
              },
            ),
            const SizedBox(height: Gap.xl),
            RpgButton(
              label: _isNew ? 'Создать задание' : 'Сохранить',
              icon: Icons.check_rounded,
              expand: true,
              loading: _busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.xs),
        child: Text(t, style: AppText.label()),
      );
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.icon, required this.label, required this.onTap, this.onClear});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => InputChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
        onDeleted: onClear,
        deleteButtonTooltipMessage: 'Убрать',
      );
}
