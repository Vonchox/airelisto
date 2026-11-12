import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/link_launcher.dart';
import '../../logic/place_classifier.dart';
import '../../models/place.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/image_placeholder.dart';
import '../../widgets/ui_extensions.dart';
import '../plans/plan_editor_screen.dart';

/// Muestra la información de un lugar en una hoja inferior.
///
/// [reason] es el motivo por el que encaja con la actividad; si no se indica
/// se calcula con la actividad seleccionada.
Future<void> showPlaceDetailSheet(
  BuildContext context,
  OutdoorPlace place, {
  String? reason,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.white,
    builder: (sheetContext) => _PlaceDetailSheet(place: place, reason: reason),
  );
}

class _PlaceDetailSheet extends StatelessWidget {
  const _PlaceDetailSheet({required this.place, this.reason});

  final OutdoorPlace place;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final settings = context.watch<SettingsProvider>();
    final location = context.watch<LocationProvider>().current;
    final formatter = settings.formatter;

    final distance = place.distanceMeters ??
        (location == null
            ? null
            : place
                .withDistanceFrom(location.latitude, location.longitude)
                .distanceMeters);
    final why = reason ??
        const PlaceClassifier().reason(settings.activity, place.kind, place.tags);
    final isFavorite = favorites.isPlaceFavorite(place);

    final details = <_Detail>[
      if (place.tags['opening_hours'] != null)
        _Detail(
          Icons.schedule_rounded,
          'Horario registrado en OpenStreetMap: ${place.tags['opening_hours']} (dato no verificado)',
        ),
      if (place.tags['surface'] != null)
        _Detail(Icons.layers_rounded, 'Superficie registrada: ${place.tags['surface']}'),
      if (place.tags['lit'] != null)
        _Detail(
          Icons.lightbulb_outline_rounded,
          'Iluminación registrada: ${place.tags['lit'] == 'yes' ? 'sí' : place.tags['lit']}',
        ),
      if (place.tags['access'] != null)
        _Detail(Icons.lock_outline_rounded, 'Acceso registrado: ${place.tags['access']}'),
    ];
    final website = place.tags['website'] ?? place.tags['contact:website'];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reserva para una imagen del lugar (assets/images/place_default.jpg).
            ImagePlaceholder(
              assetPath: AppAssets.placeDefault,
              height: 120,
              icon: place.kind.icon,
            ),
            const SizedBox(height: 16),
            Text(
              place.displayName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _InlineInfo(icon: place.kind.icon, text: place.kind.label),
                _InlineInfo(
                  icon: Icons.near_me_rounded,
                  text: distance == null
                      ? 'Distancia no disponible'
                      : 'A ${formatter.distance(distance)} (aprox.)',
                ),
              ],
            ),
            const SizedBox(height: 4),
            _InlineInfo(
              icon: Icons.place_rounded,
              text:
                  '${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}',
            ),
            const SizedBox(height: 16),
            Text(
              'Por qué puede servir para ${settings.activity.verb}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(why, style: const TextStyle(height: 1.4)),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final detail in details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(detail.icon, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(detail.text, style: const TextStyle(height: 1.35)),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'La información proviene de OpenStreetMap y puede estar incompleta o desactualizada. AireListo no verifica si el lugar está abierto, es seguro o se encuentra en buen estado.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlanEditorScreen(initialPlace: place),
                        ),
                      );
                    },
                    icon: const Icon(Icons.event_available_rounded),
                    label: const Text('Planificar aquí'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => favorites.togglePlace(place),
                  child: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite ? AppColors.warning : AppColors.forest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              children: [
                TextButton.icon(
                  onPressed: () => openExternalLink(context, place.osmUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Ver en OpenStreetMap'),
                ),
                if (website != null && website.startsWith('http'))
                  TextButton.icon(
                    onPressed: () => openExternalLink(context, website),
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Sitio web'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail {
  const _Detail(this.icon, this.text);

  final IconData icon;
  final String text;
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}
