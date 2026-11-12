import 'package:aire_listo/core/errors/app_exceptions.dart';
import 'package:aire_listo/models/air_quality.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';

void main() {
  group('AirQualityData.fromJson', () {
    test('convierte la respuesta de Open-Meteo Air Quality', () {
      final data = AirQualityData.fromJson(sampleAirQualityJson());

      expect(data.current!.usAqi, 42);
      expect(data.current!.pm25, 9.1);
      expect(data.current!.pm10, 18.5);
      expect(data.hourly, hasLength(48));
      expect(data.hasAqi, isTrue);
      expect(data.current!.category, AqiCategory.good);
    });

    test('hourAt encuentra la hora que contiene el instante', () {
      final data = AirQualityData.fromJson(sampleAirQualityJson(aqi: 77));
      final hour = data.hourAt(DateTime.utc(2026, 11, 11, 7, 45));

      expect(hour, isNotNull);
      expect(hour!.time, DateTime.utc(2026, 11, 11, 7));
      expect(hour.usAqi, 77);
      expect(data.hourAt(DateTime.utc(2027, 1, 1)), isNull);
    });

    test('hasAqi es falso si todos los valores son nulos', () {
      final json = sampleAirQualityJson();
      json.remove('current');
      (json['hourly'] as Map<String, dynamic>)['us_aqi'] =
          List<num?>.filled(48, null);

      expect(AirQualityData.fromJson(json).hasAqi, isFalse);
    });

    test('lanza UnexpectedResponseException si falta hourly', () {
      final json = sampleAirQualityJson()..remove('hourly');

      expect(
        () => AirQualityData.fromJson(json),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });
  });

  group('AqiCategory.fromUsAqi (escala US AQI)', () {
    test('clasifica según los cortes de la EPA', () {
      expect(AqiCategory.fromUsAqi(0), AqiCategory.good);
      expect(AqiCategory.fromUsAqi(50), AqiCategory.good);
      expect(AqiCategory.fromUsAqi(51), AqiCategory.moderate);
      expect(AqiCategory.fromUsAqi(100), AqiCategory.moderate);
      expect(AqiCategory.fromUsAqi(101), AqiCategory.unhealthySensitive);
      expect(AqiCategory.fromUsAqi(150), AqiCategory.unhealthySensitive);
      expect(AqiCategory.fromUsAqi(151), AqiCategory.unhealthy);
      expect(AqiCategory.fromUsAqi(200), AqiCategory.unhealthy);
      expect(AqiCategory.fromUsAqi(201), AqiCategory.veryUnhealthy);
      expect(AqiCategory.fromUsAqi(300), AqiCategory.veryUnhealthy);
      expect(AqiCategory.fromUsAqi(301), AqiCategory.hazardous);
      expect(AqiCategory.fromUsAqi(null), isNull);
    });

    test('solo advierte precaución desde "dañina para grupos sensibles"', () {
      expect(AqiCategory.good.needsCaution, isFalse);
      expect(AqiCategory.moderate.needsCaution, isFalse);
      expect(AqiCategory.unhealthySensitive.needsCaution, isTrue);
      expect(AqiCategory.hazardous.needsCaution, isTrue);
    });
  });
}
