/// Constantes generales de la aplicación: endpoints, tiempos de espera,
/// duración de la caché y la ubicación de demostración.
class AppConstants {
  AppConstants._();

  static const String appName = 'AireListo';
  static const String appVersion = '1.0.0';

  /// Identificador de la aplicación. Lo exige la política de uso de los
  /// servidores de teselas de OpenStreetMap (User-Agent identificable).
  static const String androidPackage = 'com.example.aire_listo';
  static const String userAgent =
      'AireListo/1.0 (proyecto academico no comercial; Flutter)';

  // ---- Open-Meteo (https://open-meteo.com) --------------------------------
  static const String weatherHost = 'api.open-meteo.com';
  static const String weatherPath = '/v1/forecast';

  static const String airQualityHost = 'air-quality-api.open-meteo.com';
  static const String airQualityPath = '/v1/air-quality';

  static const String geocodingHost = 'geocoding-api.open-meteo.com';
  static const String geocodingPath = '/v1/search';

  /// Días de pronóstico solicitados (incluye el día actual).
  static const int forecastDays = 5;

  // ---- Overpass API (OpenStreetMap) ---------------------------------------
  /// Se prueba en orden. Si la instancia principal está saturada se intenta
  /// con la siguiente. Todas son instancias públicas y gratuitas.
  static const List<String> overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

  // ---- Red y caché ---------------------------------------------------------
  static const Duration requestTimeout = Duration(seconds: 15);
  static const Duration overpassTimeout = Duration(seconds: 40);

  /// Tiempo durante el cual se reutilizan los datos meteorológicos.
  static const Duration weatherCacheTtl = Duration(minutes: 15);

  /// Tiempo durante el cual se reutilizan los resultados de lugares.
  static const Duration placesCacheTtl = Duration(minutes: 30);

  /// Espera tras la última pulsación antes de buscar ciudades.
  static const Duration searchDebounce = Duration(milliseconds: 450);

  // ---- Lugares -------------------------------------------------------------
  static const List<int> searchRadiusOptionsMeters = [2000, 5000, 10000];
  static const int defaultSearchRadiusMeters = 5000;

  // ---- Ubicación de demostración -------------------------------------------
  // Solo se usa si el usuario no concede permiso de GPS y todavía no eligió
  // una ciudad. La interfaz la identifica claramente como "demostración".
  static const String demoLocationName = 'Quito';
  static const String demoLocationRegion = 'Pichincha';
  static const String demoLocationCountry = 'Ecuador';
  static const double demoLatitude = -0.22985;
  static const double demoLongitude = -78.52495;
}
