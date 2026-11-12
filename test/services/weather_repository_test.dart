import 'package:aire_listo/core/errors/app_exceptions.dart';
import 'package:aire_listo/models/geo_location.dart';
import 'package:aire_listo/services/air_quality_service.dart';
import 'package:aire_listo/services/api_client.dart';
import 'package:aire_listo/services/weather_repository.dart';
import 'package:aire_listo/services/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fixtures.dart';

const _quito = GeoLocation(name: 'Quito', latitude: -0.2299, longitude: -78.51);

class _Harness {
  _Harness({
    this.weatherStatus = 200,
    this.airStatus = 200,
    this.airJson,
    DateTime? start,
  }) : now = start ?? DateTime(2026, 11, 10, 9) {
    final api = ApiClient(client: MockClient(_handle));
    repository = WeatherRepository(
      weatherService: WeatherService(api),
      airQualityService: AirQualityService(api),
      ttl: const Duration(minutes: 15),
      clock: () => now,
    );
  }

  int weatherStatus;
  int airStatus;
  Map<String, dynamic>? airJson;
  DateTime now;
  int weatherCalls = 0;
  int airCalls = 0;
  late final WeatherRepository repository;

  Future<http.Response> _handle(http.Request request) async {
    if (request.url.host.startsWith('air-quality')) {
      airCalls++;
      return airStatus == 200
          ? jsonResponse(airJson ?? sampleAirQualityJson())
          : http.Response('', airStatus);
    }
    weatherCalls++;
    return weatherStatus == 200
        ? jsonResponse(sampleWeatherJson())
        : http.Response('', weatherStatus);
  }
}

void main() {
  group('WeatherRepository', () {
    test('combina pronóstico y calidad del aire', () async {
      final h = _Harness();
      final bundle = await h.repository.load(_quito);

      expect(bundle.weather.hourly, isNotEmpty);
      expect(bundle.airQuality, isNotNull);
      expect(bundle.airQualityError, isNull);
      expect(bundle.fetchedAt, h.now);
      expect(bundle.location.name, 'Quito');
    });

    test('reutiliza la caché mientras no caduque', () async {
      final h = _Harness();
      await h.repository.load(_quito);
      h.now = h.now.add(const Duration(minutes: 14));
      await h.repository.load(_quito);

      expect(h.weatherCalls, 1);
      expect(h.airCalls, 1);
      expect(h.repository.networkFetchCount, 1);
    });

    test('vuelve a consultar cuando la caché caduca', () async {
      final h = _Harness();
      await h.repository.load(_quito);
      h.now = h.now.add(const Duration(minutes: 16));
      final second = await h.repository.load(_quito);

      expect(h.weatherCalls, 2);
      expect(second.fetchedAt, h.now);
    });

    test('forceRefresh ignora la caché', () async {
      final h = _Harness();
      await h.repository.load(_quito);
      await h.repository.load(_quito, forceRefresh: true);

      expect(h.weatherCalls, 2);
    });

    test('puntos a menos de ~1 km comparten caché', () async {
      final h = _Harness();
      await h.repository.load(_quito);
      await h.repository.load(
        const GeoLocation(name: 'Cerca', latitude: -0.2301, longitude: -78.5104),
      );

      expect(h.weatherCalls, 1);
    });

    test('las solicitudes simultáneas se unifican', () async {
      final h = _Harness();
      final results = await Future.wait([
        h.repository.load(_quito),
        h.repository.load(_quito),
        h.repository.load(_quito),
      ]);

      expect(h.weatherCalls, 1);
      expect(results.map((b) => b.fetchedAt).toSet(), hasLength(1));
    });

    test('un fallo de la calidad del aire no impide mostrar el pronóstico', () async {
      final h = _Harness(airStatus: 500);
      final bundle = await h.repository.load(_quito);

      expect(bundle.weather.hourly, isNotEmpty);
      expect(bundle.airQuality, isNull);
      expect(bundle.airQualityError, isNotEmpty);
    });

    test('avisa si la API no trae valores de AQI', () async {
      final json = sampleAirQualityJson();
      json.remove('current');
      (json['hourly'] as Map<String, dynamic>)['us_aqi'] = List<num?>.filled(48, null);
      final h = _Harness(airJson: json);
      final bundle = await h.repository.load(_quito);

      expect(bundle.airQuality, isNotNull);
      expect(bundle.airQualityError, contains('calidad del aire'));
    });

    test('un fallo del pronóstico se propaga y no se guarda en caché', () async {
      final h = _Harness(weatherStatus: 500);

      await expectLater(h.repository.load(_quito), throwsA(isA<ServerException>()));
      expect(h.repository.cachedFor(_quito), isNull);

      h.weatherStatus = 200;
      final bundle = await h.repository.load(_quito);
      expect(bundle.weather.hourly, isNotEmpty);
      expect(h.repository.cachedFor(_quito), isNotNull);
    });

    test('cachedFor devuelve el último dato aunque haya caducado', () async {
      final h = _Harness();
      await h.repository.load(_quito);
      h.now = h.now.add(const Duration(hours: 3));

      expect(h.repository.cachedFor(_quito), isNotNull);
    });
  });
}
