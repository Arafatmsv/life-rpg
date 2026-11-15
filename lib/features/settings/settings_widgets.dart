import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/widgets/rpg_card.dart';

/// Titled group of settings rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children, this.footer});
  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: Gap.xs),
            child: Text(title.toUpperCase(), style: AppText.label()),
          ),
          RpgCard(padding: const EdgeInsets.symmetric(vertical: Gap.xxs), child: Column(children: children)),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, Gap.xs, 4, 0),
              child: Text(footer!, style: AppText.ui(12, color: AppColors.textMuted, height: 1.4)),
            ),
        ]),
      );
}

Future<String?> pickTime(BuildContext context, String current) async {
  final p = current.split(':');
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0),
  );
  if (t == null) return null;
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
