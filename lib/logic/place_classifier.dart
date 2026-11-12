import 'dart:math' as math;

import '../models/activity_type.dart';
import '../models/place.dart';

/// Opción de filtro que se muestra como chip en la pantalla Explorar.
class PlaceFilterOption {
  const PlaceFilterOption(this.label, this.kinds);

  final String label;
  final Set<PlaceKind> kinds;
}

/// Interpreta las etiquetas de OpenStreetMap y decide qué tan compatible es un
/// lugar con cada actividad.
///
/// Los motivos que genera se basan **solo** en las etiquetas registradas: no
/// afirman que el lugar esté abierto, sea seguro o esté en buen estado.
class PlaceClassifier {
  const PlaceClassifier();

  /// Determina el tipo de espacio a partir de las etiquetas.
  PlaceKind classify(Map<String, String> tags) {
    final highway = tags['highway'];
    final route = tags['route'];
    final leisure = tags['leisure'];
    final landuse = tags['landuse'];
    final sport = tags['sport'];

    if (route == 'bicycle' || route == 'mtb') return PlaceKind.bicycleRoute;
    if (route == 'hiking' || route == 'foot' || route == 'running') {
      return PlaceKind.hikingRoute;
    }
    if (highway == 'cycleway') return PlaceKind.cycleway;

    if (leisure == 'track') {
      if (_hasSport(sport, const {'cycling', 'bmx'})) return PlaceKind.cyclingTrack;
      return PlaceKind.athleticsTrack;
    }
    if (leisure != null && _hasSport(sport, const {'athletics', 'running'})) {
      return PlaceKind.athleticsTrack;
    }

    if (leisure == 'park') return PlaceKind.park;
    if (leisure == 'garden') return PlaceKind.garden;
    if (leisure == 'nature_reserve') return PlaceKind.natureReserve;
    if (leisure == 'recreation_ground' || landuse == 'recreation_ground') {
      return PlaceKind.recreationArea;
    }
    if (leisure == 'pitch' ||
        leisure == 'sports_centre' ||
        leisure == 'fitness_station') {
      return PlaceKind.sportsPitch;
    }

    if (highway == 'path' && _isBicycleFriendly(tags)) return PlaceKind.sharedPath;
    if (highway == 'footway' || highway == 'path' || highway == 'pedestrian') {
      return PlaceKind.footpath;
    }
    return PlaceKind.other;
  }

  /// Compatibilidad (0 a 1) del lugar con la actividad. 0 significa que no se
  /// recomienda para esa actividad (o que OSM indica acceso restringido).
  double compatibility(
    ActivityType activity,
    PlaceKind kind,
    Map<String, String> tags,
  ) {
    final access = tags['access'];
    if (access == 'private' || access == 'no') return 0;

    double value = _baseCompatibility[activity]?[kind] ?? 0.0;

    if (activity == ActivityType.cycling) {
      final bicycle = tags['bicycle'];
      if (bicycle == 'no') return 0;
      if (bicycle == 'designated') {
        value = math.max(value, 0.85);
      } else if (bicycle == 'yes') {
        value = math.min(1.0, value + 0.15);
      }
    } else if (tags['foot'] == 'no') {
      return 0;
    }

    return math.max(0.0, math.min(1.0, value));
  }

  /// Texto que explica por qué el lugar encaja con la actividad.
  String reason(
    ActivityType activity,
    PlaceKind kind,
    Map<String, String> tags,
  ) {
    final base = _reasons[activity]?[kind] ??
        'Su tipo (${kind.label.toLowerCase()}) figura en OpenStreetMap como compatible con ${activity.verb}.';
    final extras = <String>[];
    if (activity == ActivityType.cycling && tags['bicycle'] == 'designated') {
      extras.add('Está etiquetado como de uso designado para bicicletas.');
    }
    if (tags['lit'] == 'yes') {
      extras.add('Figura con iluminación.');
    }
    return [base, ...extras].join(' ');
  }

  /// Filtros que se ofrecen en la pantalla Explorar para cada actividad.
  List<PlaceFilterOption> filtersFor(ActivityType activity) {
    switch (activity) {
      case ActivityType.walking:
        return const [
          PlaceFilterOption('Parques', {PlaceKind.park}),
          PlaceFilterOption('Jardines y reservas', {
            PlaceKind.garden,
            PlaceKind.natureReserve,
          }),
          PlaceFilterOption('Senderos', {
            PlaceKind.footpath,
            PlaceKind.hikingRoute,
          }),
          PlaceFilterOption('Recreativos', {PlaceKind.recreationArea}),
        ];
      case ActivityType.running:
        return const [
          PlaceFilterOption('Parques', {PlaceKind.park}),
          PlaceFilterOption('Pistas', {
            PlaceKind.athleticsTrack,
            PlaceKind.sportsPitch,
          }),
          PlaceFilterOption('Senderos', {
            PlaceKind.footpath,
            PlaceKind.hikingRoute,
            PlaceKind.sharedPath,
          }),
          PlaceFilterOption('Recreativos', {
            PlaceKind.recreationArea,
            PlaceKind.natureReserve,
          }),
        ];
      case ActivityType.cycling:
        return const [
          PlaceFilterOption('Ciclovías', {
            PlaceKind.cycleway,
            PlaceKind.sharedPath,
          }),
          PlaceFilterOption('Rutas y pistas', {
            PlaceKind.bicycleRoute,
            PlaceKind.cyclingTrack,
          }),
          PlaceFilterOption('Parques y recreativos', {
            PlaceKind.park,
            PlaceKind.recreationArea,
            PlaceKind.natureReserve,
          }),
        ];
    }
  }

  static bool _hasSport(String? sport, Set<String> wanted) {
    if (sport == null) return false;
    return sport.split(';').map((s) => s.trim()).any(wanted.contains);
  }

  static bool _isBicycleFriendly(Map<String, String> tags) {
    final bicycle = tags['bicycle'];
    return bicycle == 'designated' || bicycle == 'yes';
  }

  static const Map<ActivityType, Map<PlaceKind, double>> _baseCompatibility = {
    ActivityType.walking: {
      PlaceKind.park: 1.0,
      PlaceKind.garden: 0.9,
      PlaceKind.natureReserve: 0.9,
      PlaceKind.hikingRoute: 0.85,
      PlaceKind.footpath: 0.8,
      PlaceKind.recreationArea: 0.75,
      PlaceKind.sharedPath: 0.7,
      PlaceKind.athleticsTrack: 0.5,
      PlaceKind.cycleway: 0.4,
      PlaceKind.bicycleRoute: 0.35,
      PlaceKind.sportsPitch: 0.2,
    },
    ActivityType.running: {
      PlaceKind.athleticsTrack: 1.0,
      PlaceKind.park: 0.9,
      PlaceKind.footpath: 0.8,
      PlaceKind.sharedPath: 0.75,
      PlaceKind.recreationArea: 0.7,
      PlaceKind.natureReserve: 0.65,
      PlaceKind.hikingRoute: 0.6,
      PlaceKind.cycleway: 0.5,
      PlaceKind.sportsPitch: 0.45,
      PlaceKind.garden: 0.45,
      PlaceKind.bicycleRoute: 0.2,
    },
    ActivityType.cycling: {
      PlaceKind.cycleway: 1.0,
      PlaceKind.bicycleRoute: 0.95,
      PlaceKind.cyclingTrack: 0.9,
      PlaceKind.sharedPath: 0.85,
      PlaceKind.park: 0.55,
      PlaceKind.recreationArea: 0.5,
      PlaceKind.natureReserve: 0.35,
      PlaceKind.hikingRoute: 0.3,
      PlaceKind.garden: 0.2,
      PlaceKind.footpath: 0.15,
    },
  };

  static const Map<ActivityType, Map<PlaceKind, String>> _reasons = {
    ActivityType.walking: {
      PlaceKind.park:
          'Figura como parque en OpenStreetMap, un tipo de espacio abierto habitual para pasear.',
      PlaceKind.garden:
          'Figura como jardín en OpenStreetMap, un entorno habitual para paseos tranquilos.',
      PlaceKind.natureReserve:
          'Reserva natural registrada en OpenStreetMap: un entorno natural habitual para caminatas.',
      PlaceKind.hikingRoute:
          'Ruta de senderismo registrada en OpenStreetMap, pensada para recorrerse a pie.',
      PlaceKind.footpath:
          'Sendero o vía peatonal registrada en OpenStreetMap.',
      PlaceKind.recreationArea:
          'Área recreativa registrada en OpenStreetMap, con espacio abierto para pasear.',
      PlaceKind.sharedPath:
          'Sendero compartido con bicicletas según OpenStreetMap; también se puede recorrer a pie.',
      PlaceKind.athleticsTrack:
          'Pista registrada en OpenStreetMap; puede servir para caminar, aunque está pensada para correr.',
    },
    ActivityType.running: {
      PlaceKind.athleticsTrack:
          'Pista de atletismo o de carrera registrada en OpenStreetMap, un espacio pensado para correr.',
      PlaceKind.park:
          'Los parques suelen ofrecer espacios continuos para trotar; figura como parque en OpenStreetMap.',
      PlaceKind.footpath:
          'Sendero o vía peatonal registrada en OpenStreetMap, apta en principio para correr.',
      PlaceKind.sharedPath:
          'Sendero compartido registrado en OpenStreetMap, con trazado continuo para correr.',
      PlaceKind.recreationArea:
          'Área recreativa registrada en OpenStreetMap, con espacio abierto para entrenar.',
      PlaceKind.natureReserve:
          'Reserva natural registrada en OpenStreetMap; permite recorridos en entorno natural.',
      PlaceKind.hikingRoute:
          'Ruta registrada en OpenStreetMap que puede servir para correr por senderos.',
    },
    ActivityType.cycling: {
      PlaceKind.cycleway:
          'Ciclovía registrada en OpenStreetMap: infraestructura pensada para bicicletas.',
      PlaceKind.bicycleRoute:
          'Ruta para bicicletas registrada en OpenStreetMap.',
      PlaceKind.cyclingTrack:
          'Pista de ciclismo registrada en OpenStreetMap.',
      PlaceKind.sharedPath:
          'Sendero compartido marcado como apto para bicicletas en OpenStreetMap.',
      PlaceKind.park:
          'Parque registrado en OpenStreetMap; puede ofrecer espacio recreativo para pedalear.',
      PlaceKind.recreationArea:
          'Área recreativa registrada en OpenStreetMap, con espacio para pedalear.',
    },
  };
}
