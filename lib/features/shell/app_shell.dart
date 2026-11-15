import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/brand_mark.dart';
import '../game/game_event_layer.dart';

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Dest('Главная', Icons.home_outlined, Icons.home_rounded),
  _Dest('Задания', Icons.assignment_outlined, Icons.assignment_rounded),
  _Dest('Персонаж', Icons.person_outline_rounded, Icons.person_rounded),
  _Dest('Навыки', Icons.account_tree_outlined, Icons.account_tree_rounded),
  _Dest('Профиль', Icons.insights_outlined, Icons.insights_rounded),
];

/// Bottom navigation on phones, a navigation rail on tablets and wider.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    final body = GameEventLayer(child: shell);
    if (size.isCompact) {
      // Content scrolls under the floating bar, so the blur has something
      // to show; screens add MediaQuery bottom padding to their lists.
      return Scaffold(
        extendBody: true,
        body: body,
        bottomNavigationBar: _FloatingNavBar(
          index: shell.currentIndex,
          onSelect: _go,
        ),
      );
    }
    final extended = size == WindowSize.large;
    return Scaffold(
      body: SafeArea(
        right: false,
        top: false,
        bottom: false,
        child: Row(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.borderSoft)),
              ),
              child: SafeArea(
                right: false,
                // Phones in landscape are short: the rail scrolls instead of
                // clipping its last destinations, and drops the decorative sigil.
                child: LayoutBuilder(builder: (context, c) {
                  final short = c.maxHeight < 480;
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          selectedIndex: shell.currentIndex,
                          onDestinationSelected: _go,
                          extended: extended,
                          minExtendedWidth: 210,
                          labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                          leading: short
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(top: 12, bottom: 20),
                                  child: extended
                                      ? const BrandLockup()
                                      : const BrandMark(size: 26),
                                ),
                          destinations: [
                            for (final d in _destinations)
                              NavigationRailDestination(
                                icon: Icon(d.icon),
                                selectedIcon: Icon(d.selectedIcon),
                                label: Text(d.label),
                                padding: EdgeInsets.symmetric(vertical: short ? 0 : 4),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Phone navigation: a floating bar inset from the screen edges, icons only,
/// over a light background blur. The current page sits in a soft
/// rectangle (radius 14). Labels stay available to screen readers and as
/// long-press tooltips.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  static const height = 60.0;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, bottom > 0 ? bottom : Gap.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.surface1.o(0.72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.o(0.8)),
            ),
            child: Row(children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    dest: _destinations[i],
                    selected: i == index,
                    accent: accent,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(i);
                    },
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.dest, required this.selected, required this.accent, required this.onTap});
  final _Dest dest;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: dest.label,
        child: Tooltip(
          message: dest.label,
          child: InkResponse(
            onTap: onTap,
            radius: 28,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 52,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? accent.o(0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  selected ? dest.selectedIcon : dest.icon,
                  size: 24,
                  color: selected ? accent : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
}
