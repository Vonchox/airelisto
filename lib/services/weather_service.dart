import '../core/constants/app_constants.dart';
import '../models/weather_forecast.dart';
import 'api_client.dart';

/// Consume Open-Meteo Weather Forecast API.
/// Documentación: https://open-meteo.com/en/docs
class WeatherService {
  WeatherService(this._api);

  final ApiClient _api;

  static const List<String> currentVariables = [
    'temperature_2m',
    'relative_humidity_2m',
    'apparent_temperature',
    'is_day',
    'precipitation',
    'weather_code',
    'wind_speed_10m',
  ];

  static const List<String> hourlyVariables = [
    'temperature_2m',
    'apparent_temperature',
    'precipitation_probability',
    'precipitation',
    'weather_code',
    'wind_speed_10m',
    'uv_index',
  ];

  static const List<String> dailyVariables = [
    'weather_code',
    'temperature_2m_max',
    'temperature_2m_min',
    'precipitation_sum',
    'precipitation_probability_max',
    'uv_index_max',
    'wind_speed_10m_max',
    'sunrise',
    'sunset',
  ];

  /// Construye la URL de la consulta (separada para poder probarla).
  static Uri buildUri(double latitude, double longitude) {
    return Uri.https(AppConstants.weatherHost, AppConstants.weatherPath, {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'current': currentVariables.join(','),
      'hourly': hourlyVariables.join(','),
      'daily': dailyVariables.join(','),
      'timezone': 'auto',
      'forecast_days': AppConstants.forecastDays.toString(),
      'temperature_unit': 'celsius',
      'wind_speed_unit': 'kmh',
      'precipitation_unit': 'mm',
    });
  }

  Future<WeatherForecast> fetchForecast({
    required double latitude,
    required double longitude,
  }) async {
    final json = await _api.getJson(buildUri(latitude, longitude));
    return WeatherForecast.fromJson(json);
  }
}
