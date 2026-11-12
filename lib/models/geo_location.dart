import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/json_reader.dart';

/// Ubicación geográfica seleccionada (ciudad o posición del GPS).
class GeoLocation {
  const GeoLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region,
    this.country,
  });

  /// Ubicación de demostración, usada solo si no hay GPS ni ciudad elegida.
  static const GeoLocation demo = GeoLocation(
    name: AppConstants.demoLocationName,
    region: AppConstants.demoLocationRegion,
    country: AppConstants.demoLocationCountry,
    latitude: AppConstants.demoLatitude,
    longitude: AppConstants.demoLongitude,
  );

  final String name;
  final double latitude;
  final double longitude;
  final String? region;
  final String? country;

  /// Convierte un resultado de Open-Meteo Geocoding API.
  ///
  /// Campos documentados: `name`, `latitude`, `longitude`, `admin1`, `country`.
  factory GeoLocation.fromGeocodingJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const UnexpectedResponseException(
        'Un resultado de búsqueda no incluye el nombre de la ciudad.',
      );
    }
    return GeoLocation(
      name: name.trim(),
      latitude: JsonReader.requiredDouble(json['latitude'], 'latitude'),
      longitude: JsonReader.requiredDouble(json['longitude'], 'longitude'),
      region: _cleanString(json['admin1']),
      country: _cleanString(json['country']),
    );
  }

  /// Lee una ubicación guardada localmente.
  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String) {
      throw const UnexpectedResponseException('Ubicación guardada inválida.');
    }
    return GeoLocation(
      name: name,
      latitude: JsonReader.requiredDouble(json['latitude'], 'latitude'),
      longitude: JsonReader.requiredDouble(json['longitude'], 'longitude'),
      region: _cleanString(json['region']),
      country: _cleanString(json['country']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'region': region,
        'country': country,
      };

  /// Identificador aproximado (~100 m) usado para comparar y para favoritos.
  String get id => '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';

  /// Clave de caché (~1 km): evita consultas repetidas para puntos cercanos.
  String get cacheKey =>
      '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}';

  /// Región y país, por ejemplo "Pichincha, Ecuador".
  String get subtitle => [region, country]
      .whereType<String>()
      .where((part) => part.isNotEmpty)
      .join(', ');

  static String? _cleanString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) => other is GeoLocation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
