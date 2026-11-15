import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';

/// "Условия использования · Политика конфиденциальности" footer.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final style = AppText.ui(12.5, color: AppColors.textMuted).copyWith(decoration: TextDecoration.underline);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        InkWell(
          onTap: () => context.push('/legal/terms'),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Условия использования', style: style)),
        ),
        InkWell(
          onTap: () => context.push('/legal/privacy'),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Политика конфиденциальности', style: style)),
        ),
      ],
    );
  }
}
