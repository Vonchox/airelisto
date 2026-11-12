import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/app_exceptions.dart';
import '../models/geo_location.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import 'load_status.dart';

/// Origen de la ubicación seleccionada.
enum LocationSource { gps, search, demo }

/// Ubicación seleccionada (GPS, ciudad buscada o demostración) y búsqueda de
/// ciudades.
class LocationProvider extends ChangeNotifier {
  LocationProvider({
    required this._locationService,
    required this._geocodingService,
    required this._storage,
  });

  final LocationService _locationService;
  final GeocodingService _geocodingService;
  final StorageService _storage;

  GeoLocation? _current;
  LocationSource _source = LocationSource.demo;
  bool _initializing = true;
  bool _locating = false;

  /// Mensaje informativo sobre el GPS (permiso denegado, GPS apagado...).
  String? _notice;
  bool _permissionBlocked = false;

  // Búsqueda de ciudades.
  LoadStatus _searchStatus = LoadStatus.idle;
  List<GeoLocation> _searchResults = const [];
  String? _searchError;
  String _lastQuery = '';
  int _searchRequestId = 0;

  GeoLocation? get current => _current;
  LocationSource get source => _source;
  bool get isDemo => _source == LocationSource.demo;
  bool get isInitializing => _initializing;
  bool get isLocating => _locating;
  String? get notice => _notice;
  bool get permissionBlocked => _permissionBlocked;

  LoadStatus get searchStatus => _searchStatus;
  List<GeoLocation> get searchResults => _searchResults;
  String? get searchError => _searchError;
  String get lastQuery => _lastQuery;

  /// Carga la última ubicación guardada. Si no hay, intenta usar el GPS y,
  /// como último recurso, la ubicación de demostración.
  Future<void> initialize() async {
    final saved = _storage.readJsonMap(StorageService.selectedLocationKey);
    GeoLocation? savedLocation;
    var savedSource = LocationSource.search;
    if (saved != null) {
      try {
        final locationJson = saved['location'];
        if (locationJson is Map<String, dynamic>) {
          savedLocation = GeoLocation.fromJson(locationJson);
          savedSource = LocationSource.values.firstWhere(
            (s) => s.name == saved['source'],
            orElse: () => LocationSource.search,
          );
        }
      } on AppException {
        savedLocation = null;
      }
    }

    if (savedLocation != null) {
      _current = savedLocation;
      _source = savedSource;
      _initializing = false;
      notifyListeners();
      if (_source == LocationSource.gps) {
        unawaited(_refreshGpsSilently());
      }
      return;
    }

    await _locateOrUseDemo();
    _initializing = false;
    notifyListeners();
  }

  /// Obtiene la posición del GPS por petición del usuario. Devuelve `true` si
  /// se actualizó la ubicación; si falla, conserva la anterior y deja el
  /// motivo en [notice].
  Future<bool> useCurrentPosition() async {
    if (_locating) return false;
    _locating = true;
    _notice = null;
    notifyListeners();
    try {
      final coordinates = await _locationService.getCurrentCoordinates();
      _setLocation(
        GeoLocation(
          name: 'Mi ubicación',
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
        ),
        LocationSource.gps,
      );
      _permissionBlocked = false;
      return true;
    } on LocationPermissionException catch (error) {
      _notice = error.message;
      _permissionBlocked = error.permanentlyDenied;
      return false;
    } on AppException catch (error) {
      _notice = error.message;
      return false;
    } catch (_) {
      _notice = 'No se pudo obtener tu ubicación.';
      return false;
    } finally {
      _locating = false;
      notifyListeners();
    }
  }

  Future<void> _locateOrUseDemo() async {
    _locating = true;
    notifyListeners();
    try {
      final coordinates = await _locationService.getCurrentCoordinates();
      _setLocation(
        GeoLocation(
          name: 'Mi ubicación',
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
        ),
        LocationSource.gps,
      );
    } on LocationPermissionException catch (error) {
      _permissionBlocked = error.permanentlyDenied;
      _useDemo(error.message);
    } on AppException catch (error) {
      _useDemo(error.message);
    } catch (_) {
      _useDemo('No se pudo obtener tu ubicación.');
    } finally {
      _locating = false;
    }
  }

  void _useDemo(String reason) {
    _notice = reason;
    // La ubicación de demostración no se guarda como elección del usuario.
    _current = GeoLocation.demo;
    _source = LocationSource.demo;
  }

  Future<void> _refreshGpsSilently() async {
    try {
      if (!await _locationService.canReadSilently()) return;
      final coordinates = await _locationService.getCurrentCoordinates();
      _setLocation(
        GeoLocation(
          name: 'Mi ubicación',
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
        ),
        LocationSource.gps,
      );
      notifyListeners();
    } catch (_) {
      // Se conserva la última posición guardada.
    }
  }

  /// Selecciona una ciudad (resultado de búsqueda o favorito).
  void select(GeoLocation location) {
    _notice = null;
    _setLocation(location, LocationSource.search);
    notifyListeners();
  }

  void _setLocation(GeoLocation location, LocationSource source) {
    _current = location;
    _source = source;
    _storage.writeJson(StorageService.selectedLocationKey, {
      'location': location.toJson(),
      'source': source.name,
    });
  }

  /// Busca ciudades en Open-Meteo Geocoding API.
  Future<void> searchCities(String query) async {
    final trimmed = query.trim();
    _lastQuery = trimmed;
    final requestId = ++_searchRequestId;

    if (trimmed.length < 2) {
      _searchStatus = LoadStatus.idle;
      _searchResults = const [];
      _searchError = null;
      notifyListeners();
      return;
    }

    _searchStatus = LoadStatus.loading;
    _searchError = null;
    notifyListeners();

    try {
      final results = await _geocodingService.searchCities(trimmed);
      if (requestId != _searchRequestId) return;
      _searchResults = results;
      _searchStatus = LoadStatus.ready;
    } catch (error) {
      if (requestId != _searchRequestId) return;
      _searchResults = const [];
      _searchError = describeError(error);
      _searchStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchRequestId++;
    _searchStatus = LoadStatus.idle;
    _searchResults = const [];
    _searchError = null;
    _lastQuery = '';
    notifyListeners();
  }

  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }
}
