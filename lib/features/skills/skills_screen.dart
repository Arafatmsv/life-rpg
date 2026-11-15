import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/game/achievement_catalog.dart';
import '../../core/game/skill_catalog.dart';
import '../../core/game/stats.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/rpg_icons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../../data/models/game_state.dart';
import '../game/game_controller.dart';

enum _NodeState { unlocked, available, locked }

class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key, this.initial});
  final AttributeType? initial;

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  late AttributeType _attr = widget.initial ?? AttributeType.intelligence;
  final _viewer = TransformationController();

  @override
  void didUpdateWidget(SkillsScreen old) {
    super.didUpdateWidget(old);
    if (widget.initial != null && widget.initial != old.initial) {
      setState(() => _attr = widget.initial!);
      _viewer.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _viewer.dispose();
    super.dispose();
  }

  void _select(AttributeType a) {
    setState(() => _attr = a);
    _viewer.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    final snap = ref.watch(snapshotProvider);
    if (s == null || snap == null) return const Scaffold(body: LoadingView());

    final selector = SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.windowSize.gutter),
        children: [
          for (final a in AttributeType.values) ...[
            ChoiceChipX(
              label: '${a.label} · ${snap.attributeLevels[a]!.level}',
              icon: RpgIcons.attribute(a),
              color: AppColors.attribute(a),
              selected: _attr == a,
              onTap: () => _select(a),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Дерево навыков'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.md),
            child: Tooltip(
              message: 'Очки навыков: 1 за каждый уровень персонажа и характеристик',
              child: Pill('${snap.skillPoints} SP', color: AppColors.info, icon: Icons.bolt_rounded, filled: true),
            ),
          ),
        ],
      ),
      body: AdaptiveBuilder(builder: (context, size, c) {
        final tree = _TreeCanvas(
          key: ValueKey(_attr),
          attribute: _attr,
          state: s,
          snap: snap,
          controller: _viewer,
          large: size.atLeastExpanded,
        );
        if (size.atLeastExpanded) {
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 300,
              child: ListView(
                padding: const EdgeInsets.all(Gap.md),
                children: [
                  for (final a in AttributeType.values) ...[
                    _BranchSummary(attribute: a, state: s, snap: snap, selected: a == _attr, onTap: () => _select(a)),
                    const SizedBox(height: Gap.xs),
                  ],
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: tree),
          ]);
        }
        return Column(children: [
          const SizedBox(height: Gap.xs),
          selector,
          const SizedBox(height: Gap.xs),
          Expanded(child: tree),
        ]);
      }),
    );
  }
}

class _BranchSummary extends StatelessWidget {
  const _BranchSummary({
    required this.attribute,
    required this.state,
    required this.snap,
    required this.selected,
    required this.onTap,
  });

  final AttributeType attribute;
  final GameState state;
  final GameSnapshot snap;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.attribute(attribute);
    final all = skillsOf(attribute);
    final open = all.where((s) => state.skills.containsKey(s.id)).length;
    return RpgCard(
      padding: const EdgeInsets.all(Gap.sm),
      onTap: onTap,
      borderColor: selected ? c.o(0.7) : null,
      glow: selected ? c : null,
      child: Row(children: [
        IconTile(RpgIcons.attribute(attribute), color: c, size: 36),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(attribute.label, style: AppText.ui(13.5, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            XpBar(value: open / all.length, height: 5, colors: [c.o(0.6), c], glow: false),
          ]),
        ),
        const SizedBox(width: Gap.xs),
        Text('$open/${all.length}', style: AppText.number(12.5, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _TreeCanvas extends ConsumerWidget {
  const _TreeCanvas({
    super.key,
    required this.attribute,
    required this.state,
    required this.snap,
    required this.controller,
    required this.large,
  });

  final AttributeType attribute;
  final GameState state;
  final GameSnapshot snap;
  final TransformationController controller;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(engineProvider);
    final nodes = skillsOf(attribute);
    final color = AppColors.attribute(attribute);
    final node = large ? 92.0 : 76.0;
    final colW = large ? 210.0 : 128.0;
    final rowH = large ? 170.0 : 142.0;
    final width = colW * 2 + node + 120;
    // Extra bottom room so the legend never covers the last tier.
    final height = rowH * 4 + node + 180;

    Offset center(SkillDef d) => Offset(width / 2 + d.column * colW, 60 + node / 2 + (d.tier - 1) * rowH);
    _NodeState st(SkillDef d) {
      if (state.skills.containsKey(d.id)) return _NodeState.unlocked;
      return e.skillBlocker(state, d, snap) == null ? _NodeState.available : _NodeState.locked;
    }

    final edges = [
      for (final d in nodes)
        for (final r in d.requires)
          if (skillById[r] != null)
            (center(skillById[r]!), center(d), state.skills.containsKey(r) && state.skills.containsKey(d.id),
                state.skills.containsKey(r)),
    ];

    return LayoutBuilder(builder: (context, c) {
      // Fit the tree to the available width on first show.
      final fit = math.min(1.0, c.maxWidth / width);
      return Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.6),
                radius: 1.1,
                colors: [color.o(0.10), AppColors.bg],
              ),
            ),
          ),
        ),
        InteractiveViewer(
          transformationController: controller,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(240),
          minScale: 0.4,
          maxScale: 2.5,
          child: Transform.scale(
            scale: fit,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: math.max(width, c.maxWidth / fit),
              height: height,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: (math.max(width, c.maxWidth / fit) - width) / 2,
                  top: 0,
                  width: width,
                  height: height,
                  child: Stack(clipBehavior: Clip.none, children: [
                    for (var t = 1; t <= 5; t++)
                      Positioned(
                        left: 8,
                        top: 60 + node / 2 + (t - 1) * rowH - 10,
                        child: Text('T$t', style: AppText.label(color: AppColors.textMuted.o(0.6))),
                      ),
                    Positioned.fill(child: CustomPaint(painter: _EdgePainter(edges, color))),
                    for (final d in nodes)
                      Positioned(
                        left: center(d).dx - node / 2 - 20,
                        top: center(d).dy - node / 2,
                        width: node + 40,
                        child: _SkillNode(
                          def: d,
                          state: st(d),
                          size: node,
                          color: color,
                          onTap: () => _openDetails(context, ref, d),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        Positioned(
          right: Gap.md,
          bottom: Gap.md,
          child: Column(children: [
            _ZoomButton(icon: Icons.add_rounded, tooltip: 'Приблизить', onTap: () => _zoom(1.25)),
            const SizedBox(height: 8),
            _ZoomButton(icon: Icons.remove_rounded, tooltip: 'Отдалить', onTap: () => _zoom(0.8)),
            const SizedBox(height: 8),
            _ZoomButton(
              icon: Icons.center_focus_strong_rounded,
              tooltip: 'Сбросить вид',
              onTap: () => controller.value = Matrix4.identity(),
            ),
          ]),
        ),
        Positioned(
          left: Gap.md,
          bottom: Gap.md,
          child: Wrap(spacing: 8, children: [
            Pill('Открыт', color: color, filled: true),
            const Pill('Доступен', color: AppColors.gold),
            const Pill('Закрыт', color: AppColors.textMuted),
          ]),
        ),
      ]);
    });
  }

  void _zoom(double k) {
    final m = controller.value.clone()..scale(k, k, 1);
    final scale = m.getMaxScaleOnAxis();
    if (scale < 0.4 || scale > 2.5) return;
    controller.value = m;
  }

  void _openDetails(BuildContext context, WidgetRef ref, SkillDef d) {
    showRpgSheet(context, builder: (_) => _SkillDetails(def: d));
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon),
        style: IconButton.styleFrom(backgroundColor: AppColors.surface2),
      );
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.edges, this.color);
  final List<(Offset, Offset, bool, bool)> edges;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (a, b, both, from) in edges) {
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, (a.dy + b.dy) / 2, b.dx, (a.dy + b.dy) / 2, b.dx, b.dy);
      if (both) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..color = color.o(0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = both ? 2.6 : 1.6
          ..color = both
              ? color
              : from
                  ? AppColors.gold.o(0.55)
                  : AppColors.border,
      );
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}

class _SkillNode extends StatefulWidget {
  const _SkillNode({
    required this.def,
    required this.state,
    required this.size,
    required this.color,
    required this.onTap,
  });

  final SkillDef def;
  final _NodeState state;
  final double size;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_SkillNode> createState() => _SkillNodeState();
}

class _SkillNodeState extends State<_SkillNode> with TickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(_SkillNode old) {
    super.didUpdateWidget(old);
    if (old.state != _NodeState.unlocked && widget.state == _NodeState.unlocked && Motion.enabled(context)) {
      _burst.forward(from: 0);
    }
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.state == _NodeState.available && Motion.enabled(context)) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.def;
    final s = widget.state;
    final c = switch (s) {
      _NodeState.unlocked => widget.color,
      _NodeState.available => AppColors.gold,
      _NodeState.locked => AppColors.textMuted,
    };
    return Semantics(
      button: true,
      label: '${d.title}, ${switch (s) {
        _NodeState.unlocked => 'открыт',
        _NodeState.available => 'можно открыть',
        _NodeState.locked => 'закрыт',
      }}',
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(children: [
          AnimatedBuilder(
            animation: Listenable.merge([_pulse, _burst]),
            builder: (context, child) {
              final glow = s == _NodeState.available ? 0.15 + _pulse.value * 0.25 : (s == _NodeState.unlocked ? 0.35 : 0.0);
              final burst = _burst.isAnimating ? math.sin(_burst.value * math.pi) : 0.0;
              return Transform.scale(
                scale: 1 + burst * 0.18,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: ShapeDecoration(
                    shape: const _HexBorder(),
                    gradient: RadialGradient(
                      colors: s == _NodeState.unlocked
                          ? [c.o(0.55), c.o(0.12)]
                          : [AppColors.surface2, AppColors.surface0],
                    ),
                    shadows: [
                      if (glow > 0 || burst > 0)
                        BoxShadow(color: c.o((glow + burst * 0.5).clamp(0, 1)), blurRadius: 22 + burst * 20, spreadRadius: -2),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _HexStroke(c.o(s == _NodeState.locked ? 0.45 : 0.95), s == _NodeState.unlocked ? 2.2 : 1.6),
                    child: child,
                  ),
                ),
              );
            },
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  s == _NodeState.locked ? Icons.lock_rounded : RpgIcons.attribute(d.attribute),
                  color: s == _NodeState.unlocked ? AppColors.text : c,
                  size: widget.size * 0.3,
                ),
                const SizedBox(height: 2),
                Text('${d.cost} SP', style: AppText.number(widget.size * 0.13, color: c)),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            d.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.ui(widget.size * 0.15,
                weight: FontWeight.w700, color: s == _NodeState.locked ? AppColors.textMuted : AppColors.text),
          ),
        ]),
      ),
    );
  }
}

class _HexBorder extends ShapeBorder {
  const _HexBorder();

  static Path hex(Rect r) {
    final c = r.center;
    final rad = r.width / 2;
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final o = c + Offset(math.cos(a), math.sin(a)) * rad;
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => hex(rect);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => hex(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
  @override
  ShapeBorder scale(double t) => this;
}

class _HexStroke extends CustomPainter {
  _HexStroke(this.color, this.width);
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _HexBorder.hex(Offset.zero & size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_HexStroke old) => old.color != color || old.width != width;
}

class _SkillDetails extends ConsumerWidget {
  const _SkillDetails({required this.def});
  final SkillDef def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull!;
    final snap = ref.watch(snapshotProvider)!;
    final e = ref.watch(engineProvider);
    final unlocked = s.skills[def.id];
    final blocker = e.skillBlocker(s, def, snap);
    final c = AppColors.attribute(def.attribute);
    final lvl = snap.attributeLevels[def.attribute]!.level;

    Widget req(bool ok, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 18, color: ok ? AppColors.success : AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: AppText.ui(13.5, color: ok ? AppColors.text : AppColors.textSecondary))),
          ]),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconTile(RpgIcons.attribute(def.attribute), color: c, size: 52),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${def.attribute.code} · УРОВЕНЬ ДРЕВА ${def.tier}', style: AppText.label(color: c)),
              Text(def.title, style: AppText.display(26)),
            ]),
          ),
        ]),
        const SizedBox(height: Gap.md),
        Text(def.description, style: AppText.ui(14.5, color: AppColors.textSecondary, height: 1.5)),
        const SizedBox(height: Gap.md),
        RpgCard(
          padding: const EdgeInsets.all(Gap.sm),
          child: Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.violetBright),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text('«${def.perk}» · +${(def.xpBonus * 100).round()}% XP к заданиям «${def.attribute.label}»',
                  style: AppText.ui(13.5, weight: FontWeight.w600)),
            ),
          ]),
        ),
        const SizedBox(height: Gap.md),
        Text('ТРЕБОВАНИЯ', style: AppText.label()),
        req(lvl >= def.requiredLevel, '${def.attribute.label}: уровень ${def.requiredLevel} (сейчас $lvl)'),
        for (final r in def.requires)
          req(s.skills.containsKey(r), 'Навык «${skillById[r]?.title ?? r}»'),
        if (def.requiredAchievement != null)
          req(s.achievements.containsKey(def.requiredAchievement),
              'Достижение «${achievementById[def.requiredAchievement]?.title ?? def.requiredAchievement}»'),
        req(unlocked != null || snap.skillPoints >= def.cost, 'Стоимость: ${def.cost} SP (доступно ${snap.skillPoints})'),
        const SizedBox(height: Gap.lg),
        if (unlocked != null)
          Row(children: [
            Icon(Icons.verified_rounded, color: c),
            const SizedBox(width: 8),
            Text('Навык открыт', style: AppText.ui(15, weight: FontWeight.w800, color: c)),
          ])
        else ...[
          RpgButton(
            label: 'Открыть за ${def.cost} SP',
            icon: Icons.lock_open_rounded,
            expand: true,
            onPressed: blocker != null
                ? null
                : () async {
                    final ok = await runGameAction(context, ref, (e, s) => e.unlockSkill(s, def.id));
                    if (ok && context.mounted) Navigator.pop(context);
                  },
          ),
          if (blocker != null) ...[
            const SizedBox(height: Gap.xs),
            Text(blocker, textAlign: TextAlign.center, style: AppText.ui(12.5, color: AppColors.textMuted)),
          ],
        ],
      ]),
    );
  }
}
