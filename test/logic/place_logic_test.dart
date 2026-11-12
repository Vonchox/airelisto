import 'package:aire_listo/logic/place_classifier.dart';
import 'package:aire_listo/logic/place_ranker.dart';
import 'package:aire_listo/models/activity_type.dart';
import 'package:aire_listo/models/place.dart';
import 'package:flutter_test/flutter_test.dart';

OutdoorPlace _place(
  int id,
  PlaceKind kind, {
  String? name,
  double distance = 500,
  Map<String, String> tags = const {},
}) {
  return OutdoorPlace(
    osmType: 'way',
    osmId: id,
    kind: kind,
    latitude: -0.22,
    longitude: -78.5,
    name: name,
    tags: tags,
    distanceMeters: distance,
  );
}

void main() {
  const classifier = PlaceClassifier();

  group('PlaceClassifier.classify', () {
    test('reconoce los tipos de espacio según las etiquetas de OSM', () {
      expect(classifier.classify({'leisure': 'park'}), PlaceKind.park);
      expect(classifier.classify({'leisure': 'garden'}), PlaceKind.garden);
      expect(classifier.classify({'leisure': 'nature_reserve'}), PlaceKind.natureReserve);
      expect(classifier.classify({'landuse': 'recreation_ground'}), PlaceKind.recreationArea);
      expect(classifier.classify({'highway': 'cycleway'}), PlaceKind.cycleway);
      expect(classifier.classify({'route': 'bicycle'}), PlaceKind.bicycleRoute);
      expect(classifier.classify({'route': 'hiking'}), PlaceKind.hikingRoute);
      expect(classifier.classify({'highway': 'footway'}), PlaceKind.footpath);
      expect(
        classifier.classify({'highway': 'path', 'bicycle': 'designated'}),
        PlaceKind.sharedPath,
      );
      expect(
        classifier.classify({'leisure': 'track', 'sport': 'athletics'}),
        PlaceKind.athleticsTrack,
      );
      expect(
        classifier.classify({'leisure': 'track', 'sport': 'cycling'}),
        PlaceKind.cyclingTrack,
      );
      expect(
        classifier.classify({'leisure': 'pitch', 'sport': 'soccer;athletics'}),
        PlaceKind.athleticsTrack,
      );
      expect(classifier.classify({}), PlaceKind.other);
    });
  });

  group('PlaceClassifier.compatibility', () {
    test('cada actividad prefiere sus espacios típicos', () {
      expect(classifier.compatibility(ActivityType.walking, PlaceKind.park, {}), 1.0);
      expect(
        classifier.compatibility(ActivityType.running, PlaceKind.athleticsTrack, {}),
        1.0,
      );
      expect(classifier.compatibility(ActivityType.cycling, PlaceKind.cycleway, {}), 1.0);
      expect(
        classifier.compatibility(ActivityType.cycling, PlaceKind.park, {}),
        lessThan(classifier.compatibility(ActivityType.cycling, PlaceKind.cycleway, {})),
      );
    });

    test('los espacios no aptos para la actividad tienen compatibilidad 0', () {
      expect(classifier.compatibility(ActivityType.cycling, PlaceKind.athleticsTrack, {}), 0);
      expect(classifier.compatibility(ActivityType.walking, PlaceKind.cyclingTrack, {}), 0);
      expect(classifier.compatibility(ActivityType.walking, PlaceKind.other, {}), 0);
    });

    test('respeta las etiquetas de acceso y de uso permitido', () {
      expect(
        classifier.compatibility(ActivityType.walking, PlaceKind.park, {'access': 'private'}),
        0,
      );
      expect(
        classifier.compatibility(ActivityType.walking, PlaceKind.footpath, {'foot': 'no'}),
        0,
      );
      expect(
        classifier.compatibility(ActivityType.cycling, PlaceKind.park, {'bicycle': 'no'}),
        0,
      );
      expect(
        classifier.compatibility(ActivityType.cycling, PlaceKind.park, {'bicycle': 'yes'}),
        closeTo(0.7, 1e-9),
      );
      expect(
        classifier.compatibility(
          ActivityType.cycling,
          PlaceKind.footpath,
          {'bicycle': 'designated'},
        ),
        closeTo(0.85, 1e-9),
      );
    });

    test('los filtros de cada actividad solo ofrecen tipos compatibles', () {
      for (final activity in ActivityType.values) {
        final options = classifier.filtersFor(activity);
        expect(options, isNotEmpty, reason: activity.id);
        for (final option in options) {
          for (final kind in option.kinds) {
            expect(
              classifier.compatibility(activity, kind, {}),
              greaterThan(0),
              reason: '${activity.id} / ${kind.name}',
            );
          }
        }
      }
    });
  });

  group('PlaceClassifier.reason', () {
    test('explica el motivo sin afirmar seguridad ni horarios', () {
      for (final activity in ActivityType.values) {
        for (final kind in PlaceKind.values) {
          final text = classifier.reason(activity, kind, {});
          expect(text, isNotEmpty);
          final lower = text.toLowerCase();
          expect(lower, isNot(contains('es seguro')));
          expect(lower, isNot(contains('está abierto')));
          expect(lower, isNot(contains('buen estado')));
        }
      }
    });

    test('añade detalles solo si figuran en las etiquetas', () {
      final withTags = classifier.reason(
        ActivityType.cycling,
        PlaceKind.cycleway,
        {'bicycle': 'designated', 'lit': 'yes'},
      );
      final without = classifier.reason(ActivityType.cycling, PlaceKind.cycleway, {});

      expect(withTags, contains('designado para bicicletas'));
      expect(withTags, contains('iluminación'));
      expect(without, isNot(contains('iluminación')));
    });
  });

  group('PlaceRanker', () {
    const ranker = PlaceRanker();

    test('filtra por actividad y excluye lugares incompatibles o privados', () {
      final places = [
        _place(1, PlaceKind.park, name: 'Parque Central'),
        _place(2, PlaceKind.cycleway, name: 'Ciclovía Sur'),
        _place(3, PlaceKind.athleticsTrack, name: 'Pista Municipal'),
        _place(4, PlaceKind.park, name: 'Parque Privado', tags: {'access': 'private'}),
      ];

      final cycling = ranker.rank(
        places: places,
        activity: ActivityType.cycling,
        radiusMeters: 5000,
      );
      final running = ranker.rank(
        places: places,
        activity: ActivityType.running,
        radiusMeters: 5000,
      );

      expect(cycling.map((r) => r.place.id), ['way/2', 'way/1']);
      expect(running.first.place.id, 'way/3');
      expect(running.map((r) => r.place.id), isNot(contains('way/4')));
      expect(running.first.reason, isNotEmpty);
    });

    test('ordena por compatibilidad y cercanía', () {
      final places = [
        _place(1, PlaceKind.park, name: 'Parque lejano', distance: 2000),
        _place(2, PlaceKind.park, name: 'Parque cercano', distance: 500),
        _place(3, PlaceKind.garden, name: 'Jardín muy cercano', distance: 100),
      ];

      final result = ranker.rank(
        places: places,
        activity: ActivityType.walking,
        radiusMeters: 5000,
      );

      // 0.7*1.0+0.3*0.9 > 0.7*0.9+0.3*0.98 > 0.7*1.0+0.3*0.6
      expect(result.map((r) => r.place.name), [
        'Parque cercano',
        'Jardín muy cercano',
        'Parque lejano',
      ]);
      expect(result.first.score, closeTo(0.97, 1e-9));
      expect(result.first.activity, ActivityType.walking);
    });

    test('omite elementos lineales sin nombre y agrupa los repetidos', () {
      final places = [
        _place(1, PlaceKind.cycleway, name: 'Ciclovía Norte', distance: 900),
        _place(2, PlaceKind.cycleway, name: 'Ciclovía Norte', distance: 400),
        _place(3, PlaceKind.cycleway, distance: 100),
        _place(4, PlaceKind.park, distance: 300),
      ];

      final result = ranker.rank(
        places: places,
        activity: ActivityType.cycling,
        radiusMeters: 5000,
      );

      final ids = result.map((r) => r.place.id).toList();
      expect(ids, contains('way/2'));
      expect(ids, isNot(contains('way/1')));
      expect(ids, isNot(contains('way/3')));
      // Los espacios no lineales sin nombre se conservan.
      expect(ids, contains('way/4'));
    });

    test('aplica el filtro por tipo y el límite de resultados', () {
      final places = [
        for (var i = 0; i < 10; i++) _place(i, PlaceKind.park, name: 'Parque $i'),
        _place(100, PlaceKind.garden, name: 'Jardín'),
      ];

      final onlyGardens = ranker.rank(
        places: places,
        activity: ActivityType.walking,
        radiusMeters: 5000,
        kindFilter: {PlaceKind.garden},
      );
      final limited = ranker.rank(
        places: places,
        activity: ActivityType.walking,
        radiusMeters: 5000,
        limit: 3,
      );

      expect(onlyGardens.single.place.name, 'Jardín');
      expect(limited, hasLength(3));
    });

    test('devuelve una lista vacía si no hay lugares', () {
      expect(
        ranker.rank(
          places: const [],
          activity: ActivityType.walking,
          radiusMeters: 5000,
        ),
        isEmpty,
      );
    });
  });
}
