import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
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
      return Scaffold(
        body: body,
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.borderSoft)),
          ),
          child: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                  tooltip: d.label,
                ),
            ],
          ),
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
