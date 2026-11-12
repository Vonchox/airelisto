import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/geo_location.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/load_status.dart';
import '../../providers/location_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/state_views.dart';

/// Permite cambiar la ubicación: GPS, búsqueda de ciudades o favoritas.
class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Limpia resultados de búsquedas anteriores al abrir la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LocationProvider>().clearSearch();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // Actualiza el botón para borrar el texto.
    _debounce?.cancel();
    _debounce = Timer(AppConstants.searchDebounce, () {
      if (mounted) context.read<LocationProvider>().searchCities(value);
    });
  }

  Future<void> _useGps() async {
    final provider = context.read<LocationProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await provider.useCurrentPosition();
    if (!mounted) return;
    if (ok) {
      navigator.pop();
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(provider.notice ?? 'No se pudo obtener tu ubicación.'),
        action: provider.permissionBlocked
            ? SnackBarAction(
                label: 'Ajustes',
                onPressed: provider.openAppSettings,
              )
            : null,
      ),
    );
  }

  void _select(GeoLocation location) {
    context.read<LocationProvider>().select(location);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final showingSearch = provider.lastQuery.length >= 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Elegir ubicación')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (value) {
              _debounce?.cancel();
              provider.searchCities(value);
            },
            decoration: InputDecoration(
              hintText: 'Buscar ciudad (por ejemplo, Quito)',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Borrar',
                      onPressed: () {
                        _controller.clear();
                        provider.clearSearch();
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: provider.isLocating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded, color: AppColors.forest),
              title: const Text('Usar mi ubicación actual'),
              subtitle: const Text('Se solicitará el permiso de ubicación'),
              onTap: provider.isLocating ? null : _useGps,
            ),
          ),
          const SizedBox(height: 16),
          if (showingSearch)
            ..._searchSection(provider, favorites)
          else
            ..._favoritesSection(favorites),
        ],
      ),
    );
  }

  List<Widget> _searchSection(
    LocationProvider provider,
    FavoritesProvider favorites,
  ) {
    switch (provider.searchStatus) {
      case LoadStatus.loading:
        return const [
          SizedBox(height: 160, child: LoadingView(message: 'Buscando ciudades…')),
        ];
      case LoadStatus.error:
        return [
          SizedBox(
            height: 280,
            child: ErrorView(
              title: 'No se pudo buscar',
              message: provider.searchError ?? 'Inténtalo de nuevo.',
              onRetry: () => provider.searchCities(_controller.text),
            ),
          ),
        ];
      case LoadStatus.ready:
        if (provider.searchResults.isEmpty) {
          return const [
            SizedBox(
              height: 260,
              child: EmptyView(
                icon: Icons.search_off_rounded,
                title: 'Sin resultados',
                message:
                    'No encontramos ciudades con ese nombre. Revisa la ortografía o prueba con otra ciudad cercana.',
              ),
            ),
          ];
        }
        return [
          for (final location in provider.searchResults)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LocationTile(
                location: location,
                isFavorite: favorites.isLocationFavorite(location),
                onTap: () => _select(location),
                onToggleFavorite: () => favorites.toggleLocation(location),
              ),
            ),
        ];
      case LoadStatus.idle:
        return const [];
    }
  }

  List<Widget> _favoritesSection(FavoritesProvider favorites) {
    if (favorites.locations.isEmpty) {
      return const [
        SizedBox(
          height: 240,
          child: EmptyView(
            icon: Icons.travel_explore_rounded,
            title: 'Busca una ciudad',
            message:
                'Escribe al menos dos letras para buscar. Las ubicaciones que marques como favoritas aparecerán aquí.',
          ),
        ),
      ];
    }
    return [
      Text(
        'Ubicaciones favoritas',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      const SizedBox(height: 8),
      for (final location in favorites.locations)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _LocationTile(
            location: location,
            isFavorite: true,
            onTap: () => _select(location),
            onToggleFavorite: () => favorites.toggleLocation(location),
          ),
        ),
    ];
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.location,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final GeoLocation location;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: const Icon(Icons.location_city_rounded, color: AppColors.forestSecondary),
        title: Text(location.name),
        subtitle: location.subtitle.isEmpty ? null : Text(location.subtitle),
        trailing: IconButton(
          tooltip: isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos',
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite ? AppColors.warning : AppColors.textSecondary,
          ),
          onPressed: onToggleFavorite,
        ),
      ),
    );
  }
}
