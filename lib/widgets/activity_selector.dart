import 'package:material_ui/material_ui.dart';

import '../core/constants/app_colors.dart';
import '../models/activity_type.dart';

/// Selector de actividad (Caminar / Correr / Bicicleta) con animación suave.
class ActivitySelector extends StatelessWidget {
  const ActivitySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ActivityType selected;
  final ValueChanged<ActivityType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < ActivityType.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _ActivityPill(
              activity: ActivityType.values[i],
              selected: ActivityType.values[i] == selected,
              onTap: () => onChanged(ActivityType.values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActivityPill extends StatelessWidget {
  const _ActivityPill({
    required this.activity,
    required this.selected,
    required this.onTap,
  });

  final ActivityType activity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.white : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: activity.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.forest : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.forest : AppColors.outline,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(activity.icon, color: foreground, size: 24),
              const SizedBox(height: 4),
              Text(
                activity.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
