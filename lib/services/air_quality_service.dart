import '../core/constants/app_constants.dart';
import '../models/air_quality.dart';
import 'api_client.dart';

/// Consume Open-Meteo Air Quality API.
/// Documentación: https://open-meteo.com/en/docs/air-quality-api
///
/// Se usa únicamente el índice estadounidense (`us_aqi`) para no mezclar
/// escalas.
class AirQualityService {
  AirQualityService(this._api);

  final ApiClient _api;

  static const List<String> currentVariables = ['us_aqi', 'pm10', 'pm2_5'];
  static const List<String> hourlyVariables = ['pm10', 'pm2_5', 'us_aqi'];

  static Uri buildUri(double latitude, double longitude) {
    return Uri.https(AppConstants.airQualityHost, AppConstants.airQualityPath, {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'current': currentVariables.join(','),
      'hourly': hourlyVariables.join(','),
      'timezone': 'auto',
      'forecast_days': AppConstants.forecastDays.toString(),
    });
  }

  Future<AirQualityData> fetchAirQuality({
    required double latitude,
    required double longitude,
  }) async {
    final json = await _api.getJson(buildUri(latitude, longitude));
    return AirQualityData.fromJson(json);
  }
}
