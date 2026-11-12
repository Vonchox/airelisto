import '../models/activity_type.dart';
import '../models/place.dart';
import 'place_classifier.dart';

/// Filtra y ordena los lugares según su compatibilidad con la actividad y su
/// cercanía.
///
/// Puntuación de orden = `compatibilidad * 0.7 + cercanía * 0.3`, donde la
/// cercanía vale 1 en el centro de búsqueda y 0 en el borde del radio.
class PlaceRanker {
  const PlaceRanker({
    this.classifier = const PlaceClassifier(),
    this.compatibilityWeight = 0.7,
    this.proximityWeight = 0.3,
  });

  final PlaceClassifier classifier;
  final double compatibilityWeight;
  final double proximityWeight;

  /// Devuelve los lugares compatibles con [activity], ordenados de mejor a
  /// peor. Si [kindFilter] no está vacío, solo se conservan esos tipos.
  ///
  /// * Se descartan los lugares con compatibilidad 0 (por ejemplo, acceso
  ///   privado o ciclovías para correr con `foot=no`).
  /// * Los elementos lineales (ciclovías, senderos...) sin nombre se omiten
  ///   porque OpenStreetMap los divide en muchos segmentos y no aportan
  ///   información útil al usuario.
  /// * Los elementos lineales con el mismo nombre y tipo se agrupan y se
  ///   conserva el más cercano.
  List<RankedPlace> rank({
    required List<OutdoorPlace> places,
    required ActivityType activity,
    required double radiusMeters,
    Set<PlaceKind> kindFilter = const {},
    int limit = 60,
  }) {
    final sorted = [...places]..sort(
        (a, b) => (a.distanceMeters ?? double.infinity)
            .compareTo(b.distanceMeters ?? double.infinity),
      );

    final seen = <String>{};
    final ranked = <RankedPlace>[];

    for (final place in sorted) {
      if (kindFilter.isNotEmpty && !kindFilter.contains(place.kind)) continue;

      final String key;
      if (place.kind.isLinear) {
        final name = place.name?.trim().toLowerCase();
        if (name == null || name.isEmpty) continue;
        key = 'linear|${place.kind.name}|$name';
      } else {
        key = place.id;
      }
      if (!seen.add(key)) continue;

      final compatibility =
          classifier.compatibility(activity, place.kind, place.tags);
      if (compatibility <= 0) continue;

      final distance = place.distanceMeters ?? radiusMeters;
      final proximity = radiusMeters <= 0
          ? 0.0
          : (1 - distance / radiusMeters).clamp(0.0, 1.0).toDouble();

      ranked.add(
        RankedPlace(
          place: place,
          activity: activity,
          compatibility: compatibility,
          score: compatibility * compatibilityWeight + proximity * proximityWeight,
          reason: classifier.reason(activity, place.kind, place.tags),
        ),
      );
    }

    ranked.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return (a.place.distanceMeters ?? double.infinity)
          .compareTo(b.place.distanceMeters ?? double.infinity);
    });

    return ranked.length > limit ? ranked.sublist(0, limit) : ranked;
  }
}
