import 'package:aire_listo/core/utils/date_text.dart';
import 'package:aire_listo/core/utils/geo_utils.dart';
import 'package:aire_listo/core/utils/unit_formatter.dart';
import 'package:aire_listo/models/place.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeoUtils.distanceMeters', () {
    test('la distancia entre el mismo punto es 0', () {
      expect(GeoUtils.distanceMeters(-0.23, -78.52, -0.23, -78.52), 0);
    });

    test('un grado de latitud equivale a unos 111,2 km', () {
      final meters = GeoUtils.distanceMeters(0, 0, 1, 0);
      expect(meters, closeTo(111195, 50));
    });

    test('es simétrica', () {
      final ab = GeoUtils.distanceMeters(-0.2299, -78.5250, -2.1894, -79.8891);
      final ba = GeoUtils.distanceMeters(-2.1894, -79.8891, -0.2299, -78.5250);
      expect(ab, closeTo(ba, 1e-6));
    });

    test('Quito–Guayaquil está a unos 265 km en línea recta', () {
      final meters = GeoUtils.distanceMeters(-0.2299, -78.5250, -2.1894, -79.8891);
      expect(meters, inInclusiveRange(255000, 280000));
    });

    test('distancias cortas son coherentes (~100 m)', () {
      // 0.0009° de latitud ≈ 100 m.
      final meters = GeoUtils.distanceMeters(0, 0, 0.0009, 0);
      expect(meters, closeTo(100, 1));
    });

    test('OutdoorPlace.withDistanceFrom calcula la distancia al origen', () {
      const place = OutdoorPlace(
        osmType: 'node',
        osmId: 1,
        kind: PlaceKind.park,
        latitude: 0.0009,
        longitude: 0,
      );
      final withDistance = place.withDistanceFrom(0, 0);

      expect(place.distanceMeters, isNull);
      expect(withDistance.distanceMeters, closeTo(100, 1));
      expect(withDistance.id, 'node/1');
    });
  });

  group('UnitFormatter', () {
    const metric = UnitFormatter(UnitSystem.metric);
    const imperial = UnitFormatter(UnitSystem.imperial);

    test('temperatura', () {
      expect(metric.temperature(20.4), '20°');
      expect(metric.temperature(20.4, withUnit: true), '20 °C');
      expect(imperial.temperature(0), '32°');
      expect(imperial.temperature(100, withUnit: true), '212 °F');
      expect(metric.temperature(null), '–');
    });

    test('viento', () {
      expect(metric.wind(12.4), '12 km/h');
      expect(imperial.wind(10), '6 mph');
      expect(metric.wind(null), '–');
    });

    test('distancia', () {
      expect(metric.distance(350), '350 m');
      expect(metric.distance(1500), '1.5 km');
      expect(imperial.distance(1609.344), '1.0 mi');
      expect(metric.distance(null), '–');
    });

    test('precipitación y porcentajes', () {
      expect(metric.precipitation(2.54), '2.5 mm');
      expect(imperial.precipitation(25.4), '1.00 in');
      expect(metric.percent(42.4), '42 %');
    });
  });

  group('DateText', () {
    test('formatea horas y fechas en español', () {
      final date = DateTime.utc(2026, 11, 10, 7, 5);
      expect(DateText.hour(date), '07:05');
      expect(DateText.hourRange(date, DateTime.utc(2026, 11, 10, 9)), '07:05 – 09:00');
      expect(DateText.weekday(date), 'martes');
      expect(DateText.fullDate(date), 'Martes 10 de noviembre');
      expect(DateText.numeric(date), '10/11/2026');
      expect(DateText.isoDate(date), '2026-11-10');
    });

    test('relativeDay devuelve Hoy, Mañana o el día de la semana', () {
      final today = DateTime.utc(2026, 11, 10);
      expect(DateText.relativeDay(DateTime.utc(2026, 11, 10), today), 'Hoy');
      expect(DateText.relativeDay(DateTime.utc(2026, 11, 11), today), 'Mañana');
      expect(DateText.relativeDay(DateTime.utc(2026, 11, 13), today), 'Viernes');
    });

    test('lastUpdated describe la hora de actualización', () {
      final now = DateTime(2026, 11, 10, 15, 0);
      expect(DateText.lastUpdated(DateTime(2026, 11, 10, 14, 32), now), 'hoy a las 14:32');
      expect(DateText.lastUpdated(DateTime(2026, 11, 9, 9, 10), now), 'ayer a las 09:10');
      expect(DateText.lastUpdated(DateTime(2026, 11, 1, 9, 10), now), '01/11 a las 09:10');
    });
  });
}
