import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/date_text.dart';
import '../providers/location_provider.dart';
import '../providers/weather_provider.dart';
import '../screens/location/location_search_screen.dart';

/// Botón con el nombre de la ubicación seleccionada; abre el buscador.
class LocationChip extends StatelessWidget {
  const LocationChip({super.key, this.onDark = false});

  /// `true` cuando se muestra sobre un fondo oscuro (tarjeta de Inicio).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>().current;
    final foreground = onDark ? AppColors.white : AppColors.textPrimary;
    final background = onDark
        ? AppColors.white.withValues(alpha: 0.18)
        : AppColors.white;

    return Material(
      color: background,
      shape: StadiumBorder(
        side: BorderSide(
          color: onDark ? Colors.transparent : AppColors.outline,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LocationSearchScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded, size: 18, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  location == null
                      ? 'Elegir ubicación'
                      : (location.subtitle.isEmpty
                          ? location.name
                          : '${location.name}, ${location.country ?? location.region ?? ''}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 18, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra con la hora de la última actualización y el botón para actualizar.
class LastUpdatedBar extends StatelessWidget {
  const LastUpdatedBar({super.key});

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider>();
    final updated = weather.lastUpdated;
    final text = updated == null
        ? 'Sin datos todavía'
        : 'Actualizado ${DateText.lastUpdated(updated, DateTime.now())}';

    return Row(
      children: [
        const Icon(Icons.schedule_rounded, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        weather.isRefreshing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: () => weather.refresh(force: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualizar'),
              ),
      ],
    );
  }
}
