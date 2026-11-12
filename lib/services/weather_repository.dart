import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/air_quality.dart';
import '../models/geo_location.dart';
import '../models/weather_forecast.dart';
import 'air_quality_service.dart';
import 'weather_service.dart';

/// Pronóstico y calidad del aire de una ubicación, tal como se consultaron.
class ForecastBundle {
  const ForecastBundle({
    required this.location,
    required this.weather,
    required this.fetchedAt,
    this.airQuality,
    this.airQualityError,
  });

  final GeoLocation location;
  final WeatherForecast weather;

  /// `null` si la API de calidad del aire falló; ver [airQualityError].
  final AirQualityData? airQuality;
  final String? airQualityError;

  /// Momento (reloj del dispositivo) en que se obtuvieron los datos.
  final DateTime fetchedAt;
}

/// Combina el pronóstico meteorológico y la calidad del aire y aplica una
/// caché sencilla en memoria.
///
/// * Los datos se reutilizan durante [ttl] (15 min por defecto).
/// * Las solicitudes simultáneas para la misma ubicación se unifican.
/// * Un fallo de la API de calidad del aire no impide mostrar el pronóstico.
class WeatherRepository {
  WeatherRepository({
    required this._weatherService,
    required this._airQualityService,
    Duration? ttl,
    DateTime Function()? clock,
  })  : _ttl = ttl ?? AppConstants.weatherCacheTtl,
        _clock = clock ?? DateTime.now;

  final WeatherService _weatherService;
  final AirQualityService _airQualityService;
  final Duration _ttl;
  final DateTime Function() _clock;

  final Map<String, ForecastBundle> _cache = {};
  final Map<String, Future<ForecastBundle>> _inFlight = {};

  /// Número de solicitudes reales realizadas (útil en pruebas).
  int networkFetchCount = 0;

  Future<ForecastBundle> load(
    GeoLocation location, {
    bool forceRefresh = false,
  }) async {
    final key = location.cacheKey;

    final cached = _cache[key];
    if (!forceRefresh && cached != null && _isFresh(cached)) return cached;

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = _fetch(location, key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  bool _isFresh(ForecastBundle bundle) =>
      _clock().difference(bundle.fetchedAt) < _ttl;

  Future<ForecastBundle> _fetch(GeoLocation location, String key) async {
    networkFetchCount++;

    final weatherFuture = _weatherService.fetchForecast(
      latitude: location.latitude,
      longitude: location.longitude,
    );
    // El error de calidad del aire se captura aquí para que nunca quede sin
    // manejar, incluso si el pronóstico falla primero.
    final airFuture = _airQualityService
        .fetchAirQuality(
          latitude: location.latitude,
          longitude: location.longitude,
        )
        .then<_AirOutcome>(
          (data) => _AirOutcome(data: data),
          onError: (Object error) => _AirOutcome(error: error),
        );

    final weather = await weatherFuture;
    final air = await airFuture;

    String? airError;
    if (air.error != null) {
      airError = air.error is AppException
          ? (air.error! as AppException).message
          : 'No se pudo obtener la calidad del aire.';
    } else if (air.data != null && !air.data!.hasAqi) {
      airError = 'El servicio no tiene datos de calidad del aire para esta zona.';
    }

    final bundle = ForecastBundle(
      location: location,
      weather: weather,
      airQuality: air.data,
      airQualityError: airError,
      fetchedAt: _clock(),
    );
    _cache[key] = bundle;
    return bundle;
  }

  /// Último dato en caché para la ubicación, aunque haya caducado.
  ForecastBundle? cachedFor(GeoLocation location) => _cache[location.cacheKey];
}

class _AirOutcome {
  const _AirOutcome({this.data, this.error});

  final AirQualityData? data;
  final Object? error;
}
