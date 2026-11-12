import 'package:aire_listo/models/activity_type.dart';
import 'package:aire_listo/models/geo_location.dart';
import 'package:aire_listo/models/place.dart';
import 'package:aire_listo/models/planned_activity.dart';
import 'package:aire_listo/providers/favorites_provider.dart';
import 'package:aire_listo/providers/planner_provider.dart';
import 'package:aire_listo/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<StorageService> _storage([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return StorageService(await SharedPreferences.getInstance());
}

PlannedActivity _plan(String id, DateTime date, {ActivityType? activity}) {
  return PlannedActivity(
    id: id,
    activity: activity ?? ActivityType.walking,
    dateTime: date,
    locationName: 'Quito',
    latitude: -0.23,
    longitude: -78.52,
  );
}

void main() {
  group('StorageService', () {
    test('lee valores guardados y tolera datos corruptos', () async {
      final storage = await _storage({
        'ok': '{"a": 1}',
        'lista': '[{"a": 1}, 3, {"b": 2}]',
        'malo': '{no es json',
        'tipo': '"texto"',
      });

      expect(storage.readJsonMap('ok'), {'a': 1});
      expect(storage.readJsonMap('malo'), isNull);
      expect(storage.readJsonMap('tipo'), isNull);
      expect(storage.readJsonMap('no_existe'), isNull);
      expect(storage.readJsonList('lista'), hasLength(2));
      expect(storage.readJsonList('malo'), isEmpty);
      expect(storage.readJsonList('no_existe'), isEmpty);
    });

    test('guarda y elimina valores', () async {
      final storage = await _storage();
      await storage.writeJson('k', {'x': 1});
      expect(storage.readJsonMap('k'), {'x': 1});
      await storage.remove('k');
      expect(storage.readJsonMap('k'), isNull);
    });
  });

  group('PlannedActivity', () {
    test('se guarda y se recupera sin perder datos', () {
      final plan = PlannedActivity(
        id: '1',
        activity: ActivityType.cycling,
        dateTime: DateTime(2026, 11, 12, 7, 30),
        locationName: 'Quito',
        latitude: -0.23,
        longitude: -78.52,
        placeName: 'Ciclovía Norte',
        placeLatitude: -0.22,
        placeLongitude: -78.5,
        notes: 'Llevar agua',
      );

      final restored = PlannedActivity.fromJson(plan.toJson());

      expect(restored.id, '1');
      expect(restored.activity, ActivityType.cycling);
      expect(restored.dateTime, DateTime(2026, 11, 12, 7, 30));
      expect(restored.placeName, 'Ciclovía Norte');
      expect(restored.placeLatitude, -0.22);
      expect(restored.notes, 'Llevar agua');
    });

    test('copyWith conserva el id y permite quitar el lugar', () {
      final plan = _plan('7', DateTime(2026, 11, 12)).copyWith(
        placeName: 'Parque',
        placeLatitude: 1,
        placeLongitude: 2,
      );
      final cleared = plan.copyWith(clearPlace: true, activity: ActivityType.running);

      expect(cleared.id, '7');
      expect(cleared.placeName, isNull);
      expect(cleared.placeLatitude, isNull);
      expect(cleared.activity, ActivityType.running);
    });

    test('un registro sin fecha o id es inválido', () {
      expect(() => PlannedActivity.fromJson({'id': '1'}), throwsA(anything));
      expect(
        () => PlannedActivity.fromJson({'dateTime': '2026-11-10T10:00:00'}),
        throwsA(anything),
      );
    });
  });

  group('PlannerProvider', () {
    test('crea, edita, ordena y elimina planes con persistencia', () async {
      final storage = await _storage();
      final planner = PlannerProvider(storage);
      var notifications = 0;
      planner.addListener(() => notifications++);

      await planner.save(_plan('b', DateTime(2026, 11, 12, 9)));
      await planner.save(_plan('a', DateTime(2026, 11, 11, 9)));
      expect(planner.plans.map((p) => p.id), ['a', 'b']);

      await planner.save(_plan('b', DateTime(2026, 11, 10, 18), activity: ActivityType.running));
      expect(planner.plans.map((p) => p.id), ['b', 'a']);
      expect(planner.plans.first.activity, ActivityType.running);
      expect(planner.plans, hasLength(2));

      // Un nuevo proveedor sobre el mismo almacenamiento recupera los planes.
      final reloaded = PlannerProvider(storage);
      expect(reloaded.plans.map((p) => p.id), ['b', 'a']);

      await planner.delete('b');
      expect(planner.plans.map((p) => p.id), ['a']);
      expect(PlannerProvider(storage).plans.map((p) => p.id), ['a']);
      expect(notifications, 4);
    });

    test('separa planes próximos y pasados', () async {
      final planner = PlannerProvider(await _storage());
      await planner.save(_plan('old', DateTime(2026, 11, 1, 9)));
      await planner.save(_plan('older', DateTime(2026, 10, 1, 9)));
      await planner.save(_plan('next', DateTime(2026, 11, 20, 9)));
      final now = DateTime(2026, 11, 10, 12);

      expect(planner.upcoming(now: now).map((p) => p.id), ['next']);
      expect(planner.past(now: now).map((p) => p.id), ['old', 'older']);
    });

    test('ignora los planes guardados con formato inválido', () async {
      final storage = await _storage({
        StorageService.plansKey:
            '[{"id": "x"}, {"id":"ok","activity":"walking","dateTime":"2026-11-10T10:00:00","locationName":"Q","latitude":1,"longitude":2}]',
      });

      expect(PlannerProvider(storage).plans.map((p) => p.id), ['ok']);
    });

    test('newId genera identificadores distintos', () async {
      final planner = PlannerProvider(await _storage());
      final first = planner.newId();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      expect(planner.newId(), isNot(first));
    });
  });

  group('FavoritesProvider', () {
    const quito = GeoLocation(
      name: 'Quito',
      region: 'Pichincha',
      country: 'Ecuador',
      latitude: -0.2299,
      longitude: -78.5250,
    );
    const park = OutdoorPlace(
      osmType: 'way',
      osmId: 9,
      kind: PlaceKind.park,
      latitude: -0.22,
      longitude: -78.5,
      name: 'Parque La Carolina',
    );

    test('marca y desmarca ubicaciones y lugares, y los conserva', () async {
      final storage = await _storage();
      final favorites = FavoritesProvider(storage);
      expect(favorites.isEmpty, isTrue);

      await favorites.toggleLocation(quito);
      await favorites.togglePlace(park);
      expect(favorites.isLocationFavorite(quito), isTrue);
      expect(favorites.isPlaceFavorite(park), isTrue);
      expect(favorites.isEmpty, isFalse);

      final reloaded = FavoritesProvider(storage);
      expect(reloaded.locations.single.name, 'Quito');
      expect(reloaded.locations.single.subtitle, 'Pichincha, Ecuador');
      expect(reloaded.places.single.name, 'Parque La Carolina');

      await favorites.toggleLocation(quito);
      await favorites.removePlace(park);
      expect(favorites.isEmpty, isTrue);
      expect(FavoritesProvider(storage).isEmpty, isTrue);
    });

    test('una ubicación a menos de ~100 m cuenta como la misma', () async {
      final favorites = FavoritesProvider(await _storage());
      await favorites.toggleLocation(quito);

      expect(
        favorites.isLocationFavorite(
          const GeoLocation(name: 'Otro nombre', latitude: -0.22994, longitude: -78.52496),
        ),
        isTrue,
      );
    });

    test('ignora registros guardados con formato inválido', () async {
      final storage = await _storage({
        StorageService.favoriteLocationsKey: '[{"name": "Sin coordenadas"}]',
        StorageService.favoritePlacesKey: '[{"x": 1}]',
      });

      expect(FavoritesProvider(storage).isEmpty, isTrue);
    });
  });

  group('GeoLocation', () {
    test('fromGeocodingJson exige nombre y coordenadas', () {
      expect(
        () => GeoLocation.fromGeocodingJson({'latitude': 1.0, 'longitude': 2.0}),
        throwsA(anything),
      );
      expect(
        () => GeoLocation.fromGeocodingJson({'name': 'X', 'latitude': 1.0}),
        throwsA(anything),
      );
    });

    test('toJson y fromJson son inversos', () {
      const location = GeoLocation(
        name: 'Quito',
        region: 'Pichincha',
        country: 'Ecuador',
        latitude: -0.2299,
        longitude: -78.525,
      );
      final restored = GeoLocation.fromJson(location.toJson());

      expect(restored.name, 'Quito');
      expect(restored.latitude, -0.2299);
      expect(restored.subtitle, 'Pichincha, Ecuador');
      expect(restored, location);
    });

    test('la ubicación de demostración existe y es válida', () {
      expect(GeoLocation.demo.name, isNotEmpty);
      expect(GeoLocation.demo.latitude, inInclusiveRange(-90, 90));
      expect(GeoLocation.demo.longitude, inInclusiveRange(-180, 180));
    });
  });
}
