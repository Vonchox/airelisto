import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/geo_utils.dart';
import '../core/utils/json_reader.dart';
import '../logic/place_classifier.dart';
import '../models/activity_type.dart';
import '../models/place.dart';
import 'api_client.dart';

/// Busca lugares cercanos en OpenStreetMap con Overpass API.
/// Documentación: https://wiki.openstreetmap.org/wiki/Overpass_API
///
/// Es un servicio independiente del módulo meteorológico: un fallo aquí no
/// afecta al pronóstico.
class OverpassService {
  OverpassService(
    this._api, {
    this._classifier = const PlaceClassifier(),
    List<String>? endpoints,
  })  : _endpoints = endpoints ?? AppConstants.overpassEndpoints;

  final ApiClient _api;
  final PlaceClassifier _classifier;
  final List<String> _endpoints;

  /// Selectores de OpenStreetMap que se consultan para cada actividad.
  static const Map<ActivityType, List<String>> selectors = {
    ActivityType.walking: [
      r'["leisure"~"^(park|garden|nature_reserve|recreation_ground)$"]',
      r'["landuse"="recreation_ground"]',
      r'["route"~"^(hiking|foot)$"]',
      r'["highway"~"^(footway|path|pedestrian)$"]["name"]',
    ],
    ActivityType.running: [
      r'["leisure"="park"]',
      r'["leisure"="track"]',
      r'["sport"~"athletics|running"]',
      r'["route"~"^(running|hiking|foot)$"]',
      r'["highway"~"^(footway|path|pedestrian)$"]["name"]',
      r'["landuse"="recreation_ground"]',
    ],
    ActivityType.cycling: [
      r'["highway"="cycleway"]["name"]',
      r'["route"~"^(bicycle|mtb)$"]',
      r'["leisure"="track"]["sport"~"cycling|bmx"]',
      r'["highway"="path"]["bicycle"="designated"]["name"]',
      r'["leisure"~"^(park|recreation_ground)$"]["bicycle"!="no"]',
      r'["leisure"="nature_reserve"]["bicycle"~"^(yes|designated)$"]',
    ],
  };

  /// Construye la consulta Overpass QL para una actividad.
  static String buildQuery({
    required ActivityType activity,
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) {
    final lat = latitude.toStringAsFixed(5);
    final lon = longitude.toStringAsFixed(5);
    final buffer = StringBuffer('[out:json][timeout:25];\n(\n');
    for (final selector in selectors[activity]!) {
      buffer.writeln('  nwr(around:$radiusMeters,$lat,$lon)$selector;');
    }
    buffer.write(');\nout center tags 200;');
    return buffer.toString();
  }

  /// Lugares candidatos alrededor de las coordenadas, con su distancia al
  /// punto consultado. El filtrado y el orden se hacen en `PlaceRanker`.
  Future<List<OutdoorPlace>> searchNearby({
    required ActivityType activity,
    required double latitude,
    required double longitude,
    int radiusMeters = AppConstants.defaultSearchRadiusMeters,
  }) async {
    final query = buildQuery(
      activity: activity,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );

    AppException? lastError;
    for (final endpoint in _endpoints) {
      try {
        final json = await _api.postForm(
          Uri.parse(endpoint),
          {'data': query},
          timeout: AppConstants.overpassTimeout,
        );
        return parsePlaces(json, originLatitude: latitude, originLongitude: longitude);
      } on NoConnectionException {
        rethrow;
      } on UnexpectedResponseException {
        rethrow;
      } on AppException catch (error) {
        // Servidor saturado o caído: se intenta con la siguiente instancia.
        lastError = error;
      }
    }
    throw lastError ?? const ServiceUnavailableException();
  }

  /// Convierte la respuesta de Overpass en lugares.
  ///
  /// Campos usados (documentados en la guía de Overpass): `elements[]` con
  /// `type`, `id`, `lat`/`lon` (nodos) o `center.lat`/`center.lon` (vías y
  /// relaciones con `out center`) y `tags`.
  List<OutdoorPlace> parsePlaces(
    Map<String, dynamic> json, {
    required double originLatitude,
    required double originLongitude,
  }) {
    final elements = json['elements'];
    if (elements is! List<dynamic>) {
      throw const UnexpectedResponseException(
        'La búsqueda de lugares devolvió un formato inesperado.',
      );
    }

    // Cuando Overpass se queda sin tiempo o memoria responde 200 con un
    // "remark" y una lista vacía; se trata como servicio no disponible.
    final remark = json['remark'];
    if (elements.isEmpty && remark is String && remark.contains('runtime error')) {
      throw const ServiceUnavailableException(
        'El servicio de lugares está saturado. Inténtalo de nuevo en unos minutos o reduce el radio de búsqueda.',
      );
    }

    final places = <OutdoorPlace>[];
    for (final element in elements) {
      if (element is! Map<String, dynamic>) continue;

      final type = element['type'];
      final id = JsonReader.intOrNull(element['id']);
      if (type is! String || id == null) continue;

      double? latitude = JsonReader.doubleOrNull(element['lat']);
      double? longitude = JsonReader.doubleOrNull(element['lon']);
      final center = element['center'];
      if ((latitude == null || longitude == null) && center is Map<String, dynamic>) {
        latitude = JsonReader.doubleOrNull(center['lat']);
        longitude = JsonReader.doubleOrNull(center['lon']);
      }
      if (latitude == null || longitude == null) continue;

      final tags = <String, String>{};
      final rawTags = element['tags'];
      if (rawTags is Map<String, dynamic>) {
        rawTags.forEach((key, value) {
          if (value != null) tags[key] = value.toString();
        });
      }

      places.add(
        OutdoorPlace(
          osmType: type,
          osmId: id,
          kind: _classifier.classify(tags),
          latitude: latitude,
          longitude: longitude,
          name: _readName(tags),
          tags: tags,
          distanceMeters: GeoUtils.distanceMeters(
            originLatitude,
            originLongitude,
            latitude,
            longitude,
          ),
        ),
      );
    }
    return places;
  }

  String? _readName(Map<String, String> tags) {
    final name = (tags['name:es'] ?? tags['name'])?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }
}
