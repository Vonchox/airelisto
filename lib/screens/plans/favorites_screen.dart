import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../models/geo_location.dart';
import '../../models/place.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/image_placeholder.dart';
import '../../widgets/ui_extensions.dart';
import '../explore/place_detail_sheet.dart';

/// Ubicaciones y lugares guardados como favoritos.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favoritos'),
          bottom: TabBar(
            labelColor: AppColors.forest,
            indicatorColor: AppColors.forest,
            tabs: [
              Tab(text: 'Ubicaciones (${favorites.locations.length})'),
              Tab(text: 'Lugares (${favorites.places.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LocationsTab(locations: favorites.locations),
            _PlacesTab(places: favorites.places),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Reserva para una ilustración (assets/images/empty_favorites.png).
        const ImagePlaceholder(
          assetPath: AppAssets.emptyFavorites,
          height: 140,
          icon: Icons.favorite_border_rounded,
        ),
        const SizedBox(height: 16),
        Text(
          'Todavía no hay favoritos',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}

class _LocationsTab extends StatelessWidget {
  const _LocationsTab({required this.locations});

  final List<GeoLocation> locations;

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) {
      return const _EmptyFavorites(
        message:
            'Toca el corazón junto a tu ubicación en Inicio o en los resultados de búsqueda para guardarla.',
      );
    }
    final favorites = context.read<FavoritesProvider>();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: locations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final location = locations[index];
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          onTap: () {
            context.read<LocationProvider>().select(location);
            context.read<NavigationProvider>().goTo(NavigationProvider.home);
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.location_city_rounded, color: AppColors.forestSecondary),
            title: Text(location.name),
            subtitle: location.subtitle.isEmpty ? null : Text(location.subtitle),
            trailing: IconButton(
              tooltip: 'Eliminar de favoritos',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => favorites.removeLocation(location),
            ),
          ),
        );
      },
    );
  }
}

class _PlacesTab extends StatelessWidget {
  const _PlacesTab({required this.places});

  final List<OutdoorPlace> places;

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) {
      return const _EmptyFavorites(
        message:
            'En Explorar, toca el corazón de un lugar para guardarlo y consultarlo después.',
      );
    }
    final favorites = context.read<FavoritesProvider>();
    final location = context.watch<LocationProvider>().current;
    final formatter = context.watch<SettingsProvider>().formatter;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: places.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final place = places[index];
        final distance = location == null
            ? null
            : place
                .withDistanceFrom(location.latitude, location.longitude)
                .distanceMeters;
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          onTap: () => showPlaceDetailSheet(context, place),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: Icon(place.kind.icon, color: AppColors.forest),
            title: Text(place.displayName),
            subtitle: Text(
              distance == null
                  ? place.kind.label
                  : '${place.kind.label} · ${formatter.distance(distance)} de la ubicación elegida',
            ),
            trailing: IconButton(
              tooltip: 'Eliminar de favoritos',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => favorites.removePlace(place),
            ),
          ),
        );
      },
    );
  }
}
