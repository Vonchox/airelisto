import 'package:flutter/foundation.dart';

import '../models/geo_location.dart';
import '../models/place.dart';
import '../services/storage_service.dart';

/// Ubicaciones y lugares favoritos (se guardan localmente).
class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider(this._storage) {
    for (final json in _storage.readJsonList(StorageService.favoriteLocationsKey)) {
      try {
        _locations.add(GeoLocation.fromJson(json));
      } catch (_) {
        // Se ignoran los registros inválidos.
      }
    }
    for (final json in _storage.readJsonList(StorageService.favoritePlacesKey)) {
      try {
        _places.add(OutdoorPlace.fromJson(json));
      } catch (_) {
        // Se ignoran los registros inválidos.
      }
    }
  }

  final StorageService _storage;
  final List<GeoLocation> _locations = [];
  final List<OutdoorPlace> _places = [];

  List<GeoLocation> get locations => List.unmodifiable(_locations);
  List<OutdoorPlace> get places => List.unmodifiable(_places);

  bool get isEmpty => _locations.isEmpty && _places.isEmpty;

  bool isLocationFavorite(GeoLocation location) =>
      _locations.any((l) => l.id == location.id);

  bool isPlaceFavorite(OutdoorPlace place) => _places.any((p) => p.id == place.id);

  Future<void> toggleLocation(GeoLocation location) async {
    if (isLocationFavorite(location)) {
      _locations.removeWhere((l) => l.id == location.id);
    } else {
      _locations.add(location);
    }
    notifyListeners();
    await _persistLocations();
  }

  Future<void> togglePlace(OutdoorPlace place) async {
    if (isPlaceFavorite(place)) {
      _places.removeWhere((p) => p.id == place.id);
    } else {
      _places.add(place);
    }
    notifyListeners();
    await _persistPlaces();
  }

  Future<void> removeLocation(GeoLocation location) async {
    _locations.removeWhere((l) => l.id == location.id);
    notifyListeners();
    await _persistLocations();
  }

  Future<void> removePlace(OutdoorPlace place) async {
    _places.removeWhere((p) => p.id == place.id);
    notifyListeners();
    await _persistPlaces();
  }

  Future<void> _persistLocations() => _storage.writeJson(
        StorageService.favoriteLocationsKey,
        _locations.map((l) => l.toJson()).toList(),
      );

  Future<void> _persistPlaces() => _storage.writeJson(
        StorageService.favoritePlacesKey,
        _places.map((p) => p.toJson()).toList(),
      );
}
