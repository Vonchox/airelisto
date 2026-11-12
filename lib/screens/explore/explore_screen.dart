import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/link_launcher.dart';
import '../../models/place.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/load_status.dart';
import '../../providers/location_provider.dart';
import '../../providers/places_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/activity_selector.dart';
import '../../widgets/app_card.dart';
import '../../widgets/location_header.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui_extensions.dart';
import 'place_detail_sheet.dart';

/// "Explorar lugares": mapa interactivo y lista de espacios cercanos
/// adecuados para la actividad, obtenidos de OpenStreetMap (Overpass API).
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final MapController _mapController = MapController();
  bool _mapReady = false;
  String? _centerId;

  @override
  void initState() {
    super.initState();
    // La consulta a Overpass solo se hace cuando el usuario abre Explorar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlacesProvider>().activate();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _moveTo(LatLng point, double zoom) {
    if (!_mapReady) return;
    _mapController.move(point, zoom);
  }

  void _selectPlace(RankedPlace ranked) {
    final provider = context.read<PlacesProvider>();
    provider.select(ranked);
    _moveTo(LatLng(ranked.place.latitude, ranked.place.longitude), 16);
    showPlaceDetailSheet(context, ranked.place, reason: ranked.reason);
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>().current;
    final placesProvider = context.watch<PlacesProvider>();
    final settings = context.watch<SettingsProvider>();

    if (location == null) {
      return const Scaffold(body: LoadingView(message: 'Buscando tu ubicación…'));
    }

    final center = LatLng(location.latitude, location.longitude);
    if (_centerId == null) {
      _centerId = location.id;
    } else if (_centerId != location.id) {
      _centerId = location.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moveTo(center, 14);
      });
    }

    final selectedId = placesProvider.selected?.place.id;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () => _mapReady = true,
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.osmTileUrl,
                // Identifica la app ante los servidores de OpenStreetMap
                // (requisito de su política de uso de teselas).
                userAgentPackageName: AppConstants.androidPackage,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 44,
                    height: 44,
                    child: const _CenterMarker(),
                  ),
                  for (final ranked in placesProvider.places)
                    Marker(
                      point: LatLng(ranked.place.latitude, ranked.place.longitude),
                      width: ranked.place.id == selectedId ? 52 : 38,
                      height: ranked.place.id == selectedId ? 52 : 38,
                      child: GestureDetector(
                        onTap: () => _selectPlace(ranked),
                        child: _PlaceMarker(
                          kind: ranked.place.kind,
                          selected: ranked.place.id == selectedId,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: LocationChip(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RadiusMenu(
                          radiusMeters: settings.searchRadiusMeters,
                          onSelected: settings.setSearchRadius,
                        ),
                        const SizedBox(width: 8),
                        _RoundButton(
                          icon: Icons.refresh_rounded,
                          tooltip: 'Actualizar lugares',
                          onPressed: () => placesProvider.load(force: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const _AttributionChip(),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DraggableScrollableSheet(
              initialChildSize: 0.42,
              minChildSize: 0.14,
              maxChildSize: 0.92,
              snap: true,
              builder: (context, scrollController) {
                return _PlacesSheet(
                  scrollController: scrollController,
                  onSelectPlace: _selectPlace,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacesSheet extends StatelessWidget {
  const _PlacesSheet({
    required this.scrollController,
    required this.onSelectPlace,
  });

  final ScrollController scrollController;
  final ValueChanged<RankedPlace> onSelectPlace;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlacesProvider>();
    final settings = context.watch<SettingsProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final formatter = settings.formatter;
    final radiusText = formatter.distance(settings.searchRadiusMeters.toDouble());

    final List<Widget> content;
    switch (provider.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        content = const [
          SizedBox(
            height: 180,
            child: LoadingView(message: 'Buscando lugares cercanos…'),
          ),
        ];
      case LoadStatus.error:
        content = [
          SizedBox(
            height: 300,
            child: ErrorView(
              title: 'No se pudieron cargar los lugares',
              message:
                  '${provider.errorMessage ?? 'Inténtalo de nuevo.'}\nEl pronóstico del tiempo sigue disponible.',
              onRetry: () => provider.load(force: true),
            ),
          ),
        ];
      case LoadStatus.ready:
        if (provider.places.isEmpty) {
          content = [
            SizedBox(
              height: 320,
              child: EmptyView(
                icon: Icons.search_off_rounded,
                title: 'No encontramos lugares',
                message:
                    'No hay lugares registrados en OpenStreetMap para esta actividad dentro de $radiusText. Los datos pueden estar incompletos: prueba con un radio mayor o quita los filtros.',
                action: provider.selectedKinds.isEmpty
                    ? null
                    : OutlinedButton(
                        onPressed: provider.clearFilters,
                        child: const Text('Quitar filtros'),
                      ),
              ),
            ),
          ];
        } else {
          content = [
            for (final ranked in provider.places)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlaceCard(
                  ranked: ranked,
                  distanceText: formatter.distance(ranked.place.distanceMeters),
                  selected: provider.selected?.place.id == ranked.place.id,
                  isFavorite: favorites.isPlaceFavorite(ranked.place),
                  onTap: () => onSelectPlace(ranked),
                  onToggleFavorite: () => favorites.togglePlace(ranked.place),
                ),
              ),
          ];
        }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ActivitySelector(
            selected: settings.activity,
            onChanged: settings.setActivity,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: provider.selectedKinds.isEmpty,
                  onSelected: (_) => provider.clearFilters(),
                ),
                for (final option in provider.filterOptions) ...[
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(option.label),
                    selected: provider.isFilterSelected(option),
                    onSelected: (_) => provider.toggleFilter(option),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (provider.status == LoadStatus.ready && provider.places.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${provider.places.length} lugares en un radio de $radiusText · distancias aproximadas desde la ubicación elegida',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
            ),
          ...content,
          const SizedBox(height: 4),
          const Text(
            'Datos de OpenStreetMap (Overpass API). Pueden estar incompletos; no se verifica si un lugar está abierto, es seguro o está en buen estado.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.ranked,
    required this.distanceText,
    required this.selected,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final RankedPlace ranked;
  final String distanceText;
  final bool selected;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final place = ranked.place;
    return AppCard(
      color: selected ? AppColors.mint : null,
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(place.kind.icon, color: AppColors.forest),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${place.kind.label} · $distanceText',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  ranked.reason,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos',
            onPressed: onToggleFavorite,
            icon: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFavorite ? AppColors.warning : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterMarker extends StatelessWidget {
  const _CenterMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sky.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.sky,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 3),
          ),
        ),
      ),
    );
  }
}

class _PlaceMarker extends StatelessWidget {
  const _PlaceMarker({required this.kind, required this.selected});

  final PlaceKind kind;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.forest : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.forest, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Icon(
        kind.icon,
        size: selected ? 26 : 20,
        color: selected ? AppColors.white : AppColors.forest,
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.forest),
      ),
    );
  }
}

class _RadiusMenu extends StatelessWidget {
  const _RadiusMenu({required this.radiusMeters, required this.onSelected});

  final int radiusMeters;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Radio de búsqueda',
      initialValue: radiusMeters,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final meters in AppConstants.searchRadiusOptionsMeters)
          PopupMenuItem<int>(value: meters, child: Text('Radio de ${meters ~/ 1000} km')),
      ],
      child: Material(
        color: AppColors.white,
        elevation: 2,
        shape: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: AppColors.forest),
              const SizedBox(width: 4),
              Text(
                '${radiusMeters ~/ 1000} km',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Atribución visible exigida por la licencia ODbL de OpenStreetMap.
class _AttributionChip extends StatelessWidget {
  const _AttributionChip();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openExternalLink(context, AppConstants.osmCopyrightUrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '© Colaboradores de OpenStreetMap',
          style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
