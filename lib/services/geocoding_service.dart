import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/geo_location.dart';
import 'api_client.dart';

/// Busca ciudades con Open-Meteo Geocoding API.
/// Documentación: https://open-meteo.com/en/docs/geocoding-api
class GeocodingService {
  GeocodingService(this._api);

  final ApiClient _api;

  static Uri buildUri(String query, {int count = 10, String language = 'es'}) {
    return Uri.https(AppConstants.geocodingHost, AppConstants.geocodingPath, {
      'name': query,
      'count': count.toString(),
      'language': language,
      'format': 'json',
    });
  }

  /// Devuelve las ciudades que coinciden con [query]. Si no hay coincidencias
  /// la API omite la clave `results` y este método devuelve una lista vacía.
  Future<List<GeoLocation>> searchCities(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final json = await _api.getJson(buildUri(trimmed));
    final results = json['results'];
    if (results == null) return const [];
    if (results is! List<dynamic>) {
      throw const UnexpectedResponseException(
        'La búsqueda de ciudades devolvió un formato inesperado.',
      );
    }

    final locations = <GeoLocation>[];
    for (final item in results) {
      if (item is! Map<String, dynamic>) continue;
      try {
        locations.add(GeoLocation.fromGeocodingJson(item));
      } on UnexpectedResponseException {
        // Se omiten los resultados incompletos sin descartar los demás.
        continue;
      }
    }
    return locations;
  }
}
