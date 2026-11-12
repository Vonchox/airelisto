import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/link_launcher.dart';
import '../../core/utils/unit_formatter.dart';
import '../../providers/location_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/activity_selector.dart';
import '../../widgets/app_card.dart';
import '../../widgets/image_placeholder.dart';
import '../../widgets/section_header.dart';
import '../location/location_search_screen.dart';

/// Perfil y configuración: ubicación, unidades, preferencias, APIs y créditos.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final location = locationProvider.current;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil y ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const _AppHeader(),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Ubicación'),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppColors.forest),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location?.name ?? 'Sin ubicación',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          if (location != null && location.subtitle.isNotEmpty)
                            Text(
                              location.subtitle,
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          if (location != null)
                            Text(
                              '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (locationProvider.isDemo) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Es una ubicación de demostración. Elige una ciudad o permite el acceso al GPS para ver datos de tu zona.',
                    style: TextStyle(color: AppColors.onCautionSoft, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LocationSearchScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Cambiar ubicación'),
                    ),
                    OutlinedButton.icon(
                      onPressed: locationProvider.isLocating
                          ? null
                          : () => _useGps(context),
                      icon: const Icon(Icons.my_location_rounded),
                      label: const Text('Usar GPS'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Unidades de medida'),
          const SizedBox(height: 10),
          AppCard(
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<UnitSystem>(
                showSelectedIcon: false,
                segments: [
                  for (final system in UnitSystem.values)
                    ButtonSegment<UnitSystem>(
                      value: system,
                      label: Text(
                        system == UnitSystem.metric ? '°C · km/h' : '°F · mph',
                      ),
                    ),
                ],
                selected: {settings.units},
                onSelectionChanged: (values) => settings.setUnits(values.first),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Preferencias'),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Actividad predeterminada',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ActivitySelector(
                  selected: settings.activity,
                  onChanged: settings.setActivity,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Radio de búsqueda de lugares',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      for (final meters in AppConstants.searchRadiusOptionsMeters)
                        ButtonSegment<int>(
                          value: meters,
                          label: Text(
                            settings.units == UnitSystem.metric
                                ? '${meters ~/ 1000} km'
                                : '${(meters / 1609.344).toStringAsFixed(1)} mi',
                          ),
                        ),
                    ],
                    selected: {settings.searchRadiusMeters},
                    onSelectionChanged: (values) =>
                        settings.setSearchRadius(values.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'APIs utilizadas'),
          const SizedBox(height: 10),
          const _ApiTile(
            name: 'Open-Meteo Weather Forecast',
            description:
                'Temperatura, sensación térmica, lluvia, viento, índice UV y pronóstico de 5 días.',
            url: 'https://open-meteo.com/en/docs',
          ),
          const _ApiTile(
            name: 'Open-Meteo Air Quality',
            description: 'US AQI, PM2.5 y PM10 con pronóstico horario.',
            url: 'https://open-meteo.com/en/docs/air-quality-api',
          ),
          const _ApiTile(
            name: 'Open-Meteo Geocoding',
            description: 'Búsqueda de ciudades y sus coordenadas.',
            url: 'https://open-meteo.com/en/docs/geocoding-api',
          ),
          const _ApiTile(
            name: 'Overpass API (OpenStreetMap)',
            description: 'Búsqueda de parques, pistas, senderos y ciclovías cercanas.',
            url: 'https://wiki.openstreetmap.org/wiki/Overpass_API',
          ),
          const SizedBox(height: 12),
          const SectionHeader(title: 'Créditos y atribuciones'),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CreditText(
                  'Datos meteorológicos y de calidad del aire: Open-Meteo.com, bajo licencia CC BY 4.0. API gratuita para uso no comercial.',
                ),
                _CreditLink(
                  label: 'open-meteo.com',
                  url: 'https://open-meteo.com/',
                ),
                const Divider(height: 24),
                const _CreditText(
                  'Mapas y lugares: © colaboradores de OpenStreetMap, con licencia ODbL. Teselas servidas por tile.openstreetmap.org bajo su política de uso.',
                ),
                _CreditLink(
                  label: 'openstreetmap.org/copyright',
                  url: AppConstants.osmCopyrightUrl,
                ),
                const Divider(height: 24),
                const _CreditText(
                  'Paquetes de código abierto: flutter_map, latlong2, geolocator, provider, shared_preferences, http y url_launcher.',
                ),
                const Divider(height: 24),
                const _CreditText(
                  'AireListo es un proyecto académico no comercial. Las recomendaciones son una orientación basada en pronósticos y datos abiertos que pueden contener errores; no garantizan seguridad ni sustituyen el consejo médico o profesional.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              '${AppConstants.appName} v${AppConstants.appVersion}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _useGps(BuildContext context) async {
    final provider = context.read<LocationProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.useCurrentPosition();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Ubicación actualizada con tu posición actual.'
              : (provider.notice ?? 'No se pudo obtener tu ubicación.'),
        ),
        action: !ok && provider.permissionBlocked
            ? SnackBarAction(label: 'Ajustes', onPressed: provider.openAppSettings)
            : null,
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Reserva para el logotipo (assets/images/logo.png).
        SizedBox(
          width: 72,
          child: const ImagePlaceholder(
            assetPath: AppAssets.logo,
            height: 72,
            icon: Icons.air_rounded,
            borderRadius: 20,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 2),
              Text(
                'Elige el mejor momento y lugar para moverte al aire libre.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApiTile extends StatelessWidget {
  const _ApiTile({
    required this.name,
    required this.description,
    required this.url,
  });

  final String name;
  final String description;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        onTap: () => openExternalLink(context, url),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.forest),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditText extends StatelessWidget {
  const _CreditText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(height: 1.4, fontSize: 13.5));
  }
}

class _CreditLink extends StatelessWidget {
  const _CreditLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 36),
        alignment: Alignment.centerLeft,
      ),
      onPressed: () => openExternalLink(context, url),
      icon: const Icon(Icons.link_rounded, size: 18),
      label: Text(label),
    );
  }
}
