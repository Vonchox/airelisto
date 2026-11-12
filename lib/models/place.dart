import '../core/errors/app_exceptions.dart';
import '../core/utils/geo_utils.dart';
import '../core/utils/json_reader.dart';
import 'activity_type.dart';

/// Tipos de espacio que se reconocen a partir de las etiquetas de OpenStreetMap.
enum PlaceKind {
  park('Parque'),
  garden('Jardín'),
  natureReserve('Reserva natural'),
  recreationArea('Área recreativa'),
  athleticsTrack('Pista de atletismo'),
  sportsPitch('Instalación deportiva'),
  footpath('Sendero peatonal'),
  hikingRoute('Ruta de senderismo'),
  cycleway('Ciclovía'),
  bicycleRoute('Ruta para bicicletas'),
  cyclingTrack('Pista de ciclismo'),
  sharedPath('Sendero compartido'),
  other('Espacio al aire libre');

  const PlaceKind(this.label);

  final String label;

  /// `true` para elementos lineales (caminos, ciclovías, rutas).
  bool get isLinear =>
      this == PlaceKind.footpath ||
      this == PlaceKind.hikingRoute ||
      this == PlaceKind.cycleway ||
      this == PlaceKind.bicycleRoute ||
      this == PlaceKind.sharedPath;

  static PlaceKind fromName(String? name) => PlaceKind.values.firstWhere(
        (kind) => kind.name == name,
        orElse: () => PlaceKind.other,
      );
}

/// Lugar de interés obtenido de OpenStreetMap (vía Overpass API).
///
/// Solo contiene lo que OpenStreetMap registra. No se afirma nada sobre
/// seguridad, horarios ni estado de conservación.
class OutdoorPlace {
  const OutdoorPlace({
    required this.osmType,
    required this.osmId,
    required this.kind,
    required this.latitude,
    required this.longitude,
    this.name,
    this.tags = const {},
    this.distanceMeters,
  });

  /// `node`, `way` o `relation`.
  final String osmType;
  final int osmId;
  final PlaceKind kind;
  final double latitude;
  final double longitude;
  final String? name;
  final Map<String, String> tags;

  /// Distancia aproximada desde la ubicación consultada, en metros.
  final double? distanceMeters;

  String get id => '$osmType/$osmId';

  String get displayName => name ?? '${kind.label} (sin nombre registrado)';

  /// Enlace al objeto en openstreetmap.org.
  String get osmUrl => 'https://www.openstreetmap.org/$osmType/$osmId';

  OutdoorPlace withDistanceFrom(double latitude, double longitude) {
    return OutdoorPlace(
      osmType: osmType,
      osmId: osmId,
      kind: kind,
      latitude: this.latitude,
      longitude: this.longitude,
      name: name,
      tags: tags,
      distanceMeters: GeoUtils.distanceMeters(
        latitude,
        longitude,
        this.latitude,
        this.longitude,
      ),
    );
  }

  /// Lee un lugar guardado localmente (favoritos).
  factory OutdoorPlace.fromJson(Map<String, dynamic> json) {
    final type = json['osmType'];
    final id = JsonReader.intOrNull(json['osmId']);
    if (type is! String || id == null) {
      throw const UnexpectedResponseException('Lugar guardado inválido.');
    }
    final rawTags = json['tags'];
    final tags = <String, String>{};
    if (rawTags is Map<String, dynamic>) {
      rawTags.forEach((key, value) {
        if (value != null) tags[key] = value.toString();
      });
    }
    return OutdoorPlace(
      osmType: type,
      osmId: id,
      kind: PlaceKind.fromName(json['kind'] as String?),
      latitude: JsonReader.requiredDouble(json['latitude'], 'latitude'),
      longitude: JsonReader.requiredDouble(json['longitude'], 'longitude'),
      name: json['name'] is String ? json['name'] as String : null,
      tags: tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'osmType': osmType,
        'osmId': osmId,
        'kind': kind.name,
        'latitude': latitude,
        'longitude': longitude,
        'name': name,
        'tags': tags,
      };
}

/// Lugar ya evaluado para una actividad concreta.
class RankedPlace {
  const RankedPlace({
    required this.place,
    required this.activity,
    required this.compatibility,
    required this.score,
    required this.reason,
  });

  final OutdoorPlace place;
  final ActivityType activity;

  /// Compatibilidad del tipo de espacio con la actividad (0 a 1).
  final double compatibility;

  /// Puntuación final de ordenamiento (compatibilidad + cercanía, 0 a 1).
  final double score;

  /// Motivo por el que el lugar encaja con la actividad.
  final String reason;
}
