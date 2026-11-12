import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../logic/place_classifier.dart';
import '../logic/place_ranker.dart';
import '../models/place.dart';
import '../services/overpass_service.dart';
import 'load_status.dart';
import 'location_provider.dart';
import 'settings_provider.dart';

/// Estado de "Explorar lugares".
///
/// Es independiente del módulo meteorológico: un error de Overpass solo
/// afecta a esta sección. No consulta la red hasta que el usuario abre
/// Explorar ([activate]) y reutiliza resultados durante 30 minutos.
class PlacesProvider extends ChangeNotifier {
  PlacesProvider({
    required this._service,
    required this._locationProvider,
    required this._settings,
    this._ranker = const PlaceRanker(),
    this._classifier = const PlaceClassifier(),
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now {
    _locationProvider.addListener(_onInputsChanged);
    _settings.addListener(_onInputsChanged);
  }

  final OverpassService _service;
  final LocationProvider _locationProvider;
  final SettingsProvider _settings;
  final PlaceRanker _ranker;
  final PlaceClassifier _classifier;
  final DateTime Function() _clock;

  bool _active = false;
  LoadStatus _status = LoadStatus.idle;
  String? _errorMessage;
  List<OutdoorPlace> _candidates = const [];
  List<RankedPlace> _places = const [];
  final Set<PlaceKind> _selectedKinds = {};
  RankedPlace? _selected;
  String? _loadedKey;
  int _requestId = 0;

  final Map<String, _CacheEntry> _cache = {};

  LoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<RankedPlace> get places => _places;
  RankedPlace? get selected => _selected;
  Set<PlaceKind> get selectedKinds => Set.unmodifiable(_selectedKinds);

  /// Filtros disponibles para la actividad actual.
  List<PlaceFilterOption> get filterOptions =>
      _classifier.filtersFor(_settings.activity);

  /// Lugares candidatos más recientes (aunque no pasen el filtro actual).
  List<OutdoorPlace> get candidates => _candidates;

  @override
  void dispose() {
    _locationProvider.removeListener(_onInputsChanged);
    _settings.removeListener(_onInputsChanged);
    super.dispose();
  }

  /// Se llama cuando el usuario abre la pestaña Explorar por primera vez.
  void activate() {
    if (_active) return;
    _active = true;
    unawaited(load());
  }

  String? _currentKey() {
    final location = _locationProvider.current;
    if (location == null) return null;
    return '${_settings.activity.id}|${location.id}|${_settings.searchRadiusMeters}';
  }

  void _onInputsChanged() {
    if (!_active) return;
    final key = _currentKey();
    if (key == null || key == _loadedKey) return;
    // Al cambiar de actividad los filtros anteriores ya no aplican.
    _selectedKinds.clear();
    unawaited(load());
  }

  /// Consulta los lugares cercanos (o reutiliza la caché).
  Future<void> load({bool force = false}) async {
    final location = _locationProvider.current;
    final key = _currentKey();
    if (location == null || key == null) return;

    _loadedKey = key;
    final requestId = ++_requestId;
    _errorMessage = null;
    _selected = null;

    final cached = _cache[key];
    if (!force && cached != null && _clock().difference(cached.time) < AppConstants.placesCacheTtl) {
      _candidates = cached.places;
      _applyRanking();
      _status = LoadStatus.ready;
      notifyListeners();
      return;
    }

    _status = LoadStatus.loading;
    notifyListeners();

    try {
      final result = await _service.searchNearby(
        activity: _settings.activity,
        latitude: location.latitude,
        longitude: location.longitude,
        radiusMeters: _settings.searchRadiusMeters,
      );
      if (requestId != _requestId) return;
      _cache[key] = _CacheEntry(result, _clock());
      _candidates = result;
      _applyRanking();
      _status = LoadStatus.ready;
    } catch (error) {
      if (requestId != _requestId) return;
      _candidates = const [];
      _places = const [];
      _errorMessage = describeError(error);
      _status = LoadStatus.error;
      // Permite reintentar con el mismo criterio.
      _loadedKey = null;
    }
    notifyListeners();
  }

  void _applyRanking() {
    _places = _ranker.rank(
      places: _candidates,
      activity: _settings.activity,
      radiusMeters: _settings.searchRadiusMeters.toDouble(),
      kindFilter: _selectedKinds,
    );
    final selected = _selected;
    if (selected != null && !_places.any((p) => p.place.id == selected.place.id)) {
      _selected = null;
    }
  }

  bool isFilterSelected(PlaceFilterOption option) =>
      option.kinds.every(_selectedKinds.contains);

  /// Activa o desactiva un filtro (sin consultar la red).
  void toggleFilter(PlaceFilterOption option) {
    if (isFilterSelected(option)) {
      _selectedKinds.removeAll(option.kinds);
    } else {
      _selectedKinds.addAll(option.kinds);
    }
    _applyRanking();
    notifyListeners();
  }

  void clearFilters() {
    if (_selectedKinds.isEmpty) return;
    _selectedKinds.clear();
    _applyRanking();
    notifyListeners();
  }

  void select(RankedPlace? place) {
    _selected = place;
    notifyListeners();
  }
}

class _CacheEntry {
  const _CacheEntry(this.places, this.time);

  final List<OutdoorPlace> places;
  final DateTime time;
}
