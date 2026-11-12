import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_text.dart';
import '../../models/planned_activity.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/planner_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/image_placeholder.dart';
import '../../widgets/section_header.dart';
import 'favorites_screen.dart';
import 'plan_editor_screen.dart';

/// "Mis planes": actividades planificadas y acceso a favoritos.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  void _openEditor(BuildContext context, {PlannedActivity? plan}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlanEditorScreen(plan: plan)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, PlannedActivity plan) async {
    final planner = context.read<PlannerProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar plan'),
        content: Text(
          '¿Quieres eliminar "${plan.activity.label}" del ${DateText.numeric(plan.dateTime)} a las ${DateText.hour(plan.dateTime)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await planner.delete(plan.id);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Plan eliminado'),
        action: SnackBarAction(label: 'Deshacer', onPressed: () => planner.save(plan)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final upcoming = planner.upcoming();
    final past = planner.past();
    final favoritesCount = favorites.locations.length + favorites.places.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis planes'),
        actions: [
          IconButton(
            tooltip: 'Favoritos',
            icon: const Icon(Icons.favorite_rounded, color: AppColors.warning),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo plan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.favorite_rounded, color: AppColors.warning),
              title: const Text('Favoritos'),
              subtitle: Text(
                favoritesCount == 0
                    ? 'Guarda ubicaciones y lugares para volver a ellos'
                    : '${favorites.locations.length} ubicaciones · ${favorites.places.length} lugares',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 20),
          if (planner.plans.isEmpty)
            _EmptyPlans(onCreate: () => _openEditor(context))
          else ...[
            if (upcoming.isNotEmpty) ...[
              const SectionHeader(title: 'Próximos'),
              const SizedBox(height: 10),
              for (final plan in upcoming)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlanCard(
                    plan: plan,
                    onEdit: () => _openEditor(context, plan: plan),
                    onDelete: () => _confirmDelete(context, plan),
                  ),
                ),
            ],
            if (past.isNotEmpty) ...[
              const SizedBox(height: 10),
              const SectionHeader(title: 'Pasados'),
              const SizedBox(height: 10),
              for (final plan in past)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlanCard(
                    plan: plan,
                    isPast: true,
                    onEdit: () => _openEditor(context, plan: plan),
                    onDelete: () => _confirmDelete(context, plan),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Reserva para una ilustración (assets/images/empty_plans.png).
        const ImagePlaceholder(
          assetPath: AppAssets.emptyPlans,
          height: 150,
          icon: Icons.event_available_rounded,
        ),
        const SizedBox(height: 16),
        Text(
          'Aún no tienes planes',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Planifica una caminata, una carrera o un paseo en bicicleta y elige el mejor horario según el pronóstico.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Crear mi primer plan'),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.onEdit,
    required this.onDelete,
    this.isPast = false,
  });

  final PlannedActivity plan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final place = plan.placeName == null
        ? plan.locationName
        : '${plan.placeName} · ${plan.locationName}';

    return Opacity(
      opacity: isPast ? 0.7 : 1,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
        onTap: onEdit,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(plan.activity.icon, color: AppColors.forest),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.activity.label,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateText.fullDate(plan.dateTime)} · ${DateText.hour(plan.dateTime)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.place_rounded, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (plan.notes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      plan.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: 'Editar plan',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 20),
                ),
                IconButton(
                  tooltip: 'Eliminar plan',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
