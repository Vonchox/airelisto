import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/app_exceptions.dart';
import '../logic/recommendation_engine.dart';
import '../models/activity_type.dart';
import '../models/recommendation.dart';
import '../services/weather_repository.dart';
import 'load_status.dart';
import 'location_provider.dart';

/// Estado del pronóstico y la calidad del aire de la ubicación seleccionada,
/// y recomendaciones derivadas.
///
/// Se actualiza automáticamente cuando cambia la ubicación. Mantiene los
/// últimos datos válidos si una actualización posterior falla, indicando la
/// hora de la última actualización exitosa.
class WeatherProvider extends ChangeNotifier {
  WeatherProvider({
    required this._repository,
    required this._locationProvider,
    RecommendationEngine? engine,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        engine = engine ?? RecommendationEngine() {
    _locationProvider.addListener(_onLocationChanged);
    _onLocationChanged();
  }

  final WeatherRepository _repository;
  final LocationProvider _locationProvider;
  final DateTime Function() _clock;
  final RecommendationEngine engine;

  LoadStatus _status = LoadStatus.idle;
  ForecastBundle? _bundle;
  String? _errorMessage;
  String? _refreshError;
  bool _isRefreshing = false;
  String? _loadedLocationId;
  int _requestId = 0;
  DateTime? _selectedDate;

  final Map<String, DayRecommendation> _memo = {};

  LoadStatus get status => _status;
  ForecastBundle? get bundle => _bundle;

  /// Mensaje cuando no hay datos que mostrar.
  String? get errorMessage => _errorMessage;

  /// Mensaje cuando una actualización falló pero hay datos anteriores.
  String? get refreshError => _refreshError;
  bool get isRefreshing => _isRefreshing;
  DateTime? get lastUpdated => _bundle?.fetchedAt;
  DateTime? get selectedDate => _selectedDate;

  @override
  void dispose() {
    _locationProvider.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _onLocationChanged() {
    final location = _locationProvider.current;
    if (location == null || location.id == _loadedLocationId) return;
    _loadedLocationId = location.id;
    _bundle = null;
    _selectedDate = null;
    _memo.clear();
    unawaited(refresh());
  }

  /// Consulta los datos de la ubicación actual. Con [force] se ignora la
  /// caché (actualización manual).
  Future<void> refresh({bool force = false}) async {
    final location = _locationProvider.current;
    if (location == null) return;

    final requestId = ++_requestId;
    _status = _bundle == null ? LoadStatus.loading : LoadStatus.ready;
    _isRefreshing = true;
    _errorMessage = null;
    _refreshError = null;
    notifyListeners();

    try {
      final result = await _repository.load(location, forceRefresh: force);
      if (requestId != _requestId) return;
      _bundle = result;
      _memo.clear();
      _ensureSelectedDate();
      _status = LoadStatus.ready;
    } catch (error) {
      if (requestId != _requestId) return;
      final message = describeError(error);
      if (_bundle != null) {
        _refreshError = message;
        _status = LoadStatus.ready;
      } else {
        _errorMessage = message;
        _status = LoadStatus.error;
      }
    }
    _isRefreshing = false;
    notifyListeners();
  }

  /// Hora actual en la ubicación (hora de pared en UTC), o `null` sin datos.
  DateTime? get nowAtLocation => _bundle?.weather.nowAtLocation(now: _clock());

  /// Fecha de hoy en la ubicación (a medianoche, en UTC).
  DateTime? get todayAtLocation {
    final now = nowAtLocation;
    if (now == null) return null;
    return DateTime.utc(now.year, now.month, now.day);
  }

  void selectDate(DateTime date) {
    _selectedDate = DateTime.utc(date.year, date.month, date.day);
    notifyListeners();
  }

  void _ensureSelectedDate() {
    final bundle = _bundle;
    if (bundle == null) return;
    final selected = _selectedDate;
    final isAvailable =
        selected != null && bundle.weather.dailyFor(selected) != null;
    if (isAvailable) return;
    _selectedDate = todayAtLocation ?? bundle.weather.daily.first.date;
    if (bundle.weather.dailyFor(_selectedDate!) == null) {
      _selectedDate = bundle.weather.daily.first.date;
    }
  }

  /// Recomendaciones de un día para una actividad (con memoización: se
  /// recalculan solo cuando llegan datos nuevos).
  DayRecommendation? recommendationFor(
    ActivityType activity,
    DateTime date, {
    DateTime? notBefore,
  }) {
    final bundle = _bundle;
    if (bundle == null) return null;
    final key =
        '${activity.id}|${date.millisecondsSinceEpoch}|${notBefore?.millisecondsSinceEpoch}';
    return _memo.putIfAbsent(
      key,
      () => engine.recommendDay(
        activity: activity,
        weather: bundle.weather,
        airQuality: bundle.airQuality,
        date: date,
        notBefore: notBefore,
      ),
    );
  }

  /// Mejor recomendación disponible desde ahora: lo que queda de hoy y, si ya
  /// no quedan horas útiles, el primer día siguiente con datos.
  DayRecommendation? upcomingRecommendation(ActivityType activity) {
    final bundle = _bundle;
    final now = nowAtLocation;
    final today = todayAtLocation;
    if (bundle == null || now == null || today == null) return null;

    final notBefore = DateTime.utc(now.year, now.month, now.day, now.hour);
    final todayResult = recommendationFor(activity, today, notBefore: notBefore);
    if (todayResult != null && !todayResult.isEmpty) return todayResult;

    for (final day in bundle.weather.daily) {
      if (!day.date.isAfter(today)) continue;
      final result = recommendationFor(activity, day.date);
      if (result != null && !result.isEmpty) return result;
    }
    return null;
  }
}
