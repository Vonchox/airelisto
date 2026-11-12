import 'dart:math' as math;

/// Cálculos geográficos sencillos (sin dependencias de Flutter).
class GeoUtils {
  GeoUtils._();

  /// Radio medio de la Tierra en metros.
  static const double earthRadiusMeters = 6371008.8;

  /// Distancia aproximada sobre la superficie terrestre entre dos puntos
  /// (fórmula de Haversine), en metros.
  static double distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
}
