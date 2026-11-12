import 'package:material_ui/material_ui.dart';

import '../core/constants/app_colors.dart';

/// Título de sección con acción opcional a la derecha.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
