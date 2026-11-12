import 'dart:convert';

import 'package:aire_listo/core/errors/app_exceptions.dart';
import 'package:aire_listo/models/activity_type.dart';
import 'package:aire_listo/models/place.dart';
import 'package:aire_listo/services/air_quality_service.dart';
import 'package:aire_listo/services/api_client.dart';
import 'package:aire_listo/services/geocoding_service.dart';
import 'package:aire_listo/services/overpass_service.dart';
import 'package:aire_listo/services/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fixtures.dart';

ApiClient _client(Future<http.Response> Function(http.Request) handler,
    {Duration? timeout}) {
  return ApiClient(client: MockClient(handler), timeout: timeout);
}

void main() {
  group('ApiClient', () {
    final uri = Uri.https('example.test', '/data');

    test('decodifica JSON como UTF-8 aunque no se declare el charset', () async {
      final api = _client((_) async => jsonResponse({'ciudad': 'Bogotá'}));
      final json = await api.getJson(uri);
      expect(json['ciudad'], 'Bogotá');
    });

    test('envía un User-Agent identificable', () async {
      String? userAgent;
      final api = _client((request) async {
        userAgent = request.headers['User-Agent'];
        return jsonResponse({});
      });
      await api.getJson(uri);
      expect(userAgent, contains('AireListo'));
    });

    test('429 se traduce en RateLimitException', () async {
      final api = _client((_) async => http.Response('', 429));
      expect(api.getJson(uri), throwsA(isA<RateLimitException>()));
    });

    test('502/503/504 se traducen en ServiceUnavailableException', () async {
      for (final status in [502, 503, 504]) {
        final api = _client((_) async => http.Response('', status));
        await expectLater(api.getJson(uri), throwsA(isA<ServiceUnavailableException>()));
      }
    });

    test('otros errores del servidor lanzan ServerException con el código', () async {
      final api = _client((_) async => http.Response('boom', 500));
      await expectLater(
        api.getJson(uri),
        throwsA(isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('muestra el motivo que devuelve Open-Meteo en errores 400', () async {
      final api = _client(
        (_) async => jsonResponse({'error': true, 'reason': 'Latitude must be in range'}, status: 400),
      );
      await expectLater(
        api.getJson(uri),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Latitude must be in range'),
          ),
        ),
      );
    });

    test('un cuerpo que no es JSON lanza UnexpectedResponseException', () async {
      final api = _client((_) async => http.Response('<html>', 200));
      expect(api.getJson(uri), throwsA(isA<UnexpectedResponseException>()));
    });

    test('un JSON que no es un objeto lanza UnexpectedResponseException', () async {
      final api = _client((_) async => http.Response('[1, 2, 3]', 200));
      expect(api.getJson(uri), throwsA(isA<UnexpectedResponseException>()));
    });

    test('un error de conexión lanza NoConnectionException', () async {
      final api = _client((_) async => throw http.ClientException('sin red'));
      expect(api.getJson(uri), throwsA(isA<NoConnectionException>()));
    });

    test('un tiempo de espera agotado lanza ServiceUnavailableException', () async {
      final api = _client(
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return jsonResponse({});
        },
        timeout: const Duration(milliseconds: 20),
      );
      expect(api.getJson(uri), throwsA(isA<ServiceUnavailableException>()));
    });
  });

  group('WeatherService', () {
    test('construye la URL con las variables y timezone=auto', () {
      final uri = WeatherService.buildUri(-0.2299, -78.525);

      expect(uri.host, 'api.open-meteo.com');
      expect(uri.path, '/v1/forecast');
      final params = uri.queryParameters;
      expect(params['latitude'], '-0.2299');
      expect(params['longitude'], '-78.5250');
      expect(params['timezone'], 'auto');
      expect(params['forecast_days'], '5');
      expect(params['wind_speed_unit'], 'kmh');
      expect(params['hourly'], contains('uv_index'));
      expect(params['hourly'], contains('precipitation_probability'));
      expect(params['hourly'], contains('apparent_temperature'));
      expect(params['daily'], contains('uv_index_max'));
      expect(params['daily'], contains('temperature_2m_max'));
      expect(params['current'], contains('weather_code'));
    });

    test('obtiene y convierte el pronóstico con una respuesta simulada', () async {
      late Uri requested;
      final service = WeatherService(_client((request) async {
        requested = request.url;
        return jsonResponse(sampleWeatherJson(days: 5));
      }));

      final forecast = await service.fetchForecast(latitude: -0.23, longitude: -78.52);

      expect(requested.path, '/v1/forecast');
      expect(forecast.daily, hasLength(5));
      expect(forecast.hourly, hasLength(120));
    });

    test('propaga los errores del servidor', () async {
      final service = WeatherService(_client((_) async => http.Response('', 500)));
      expect(
        service.fetchForecast(latitude: 0, longitude: 0),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('AirQualityService', () {
    test('construye la URL con us_aqi, pm10 y pm2_5', () {
      final uri = AirQualityService.buildUri(-0.23, -78.52);

      expect(uri.host, 'air-quality-api.open-meteo.com');
      expect(uri.path, '/v1/air-quality');
      expect(uri.queryParameters['hourly'], 'pm10,pm2_5,us_aqi');
      expect(uri.queryParameters['current'], 'us_aqi,pm10,pm2_5');
      expect(uri.queryParameters['timezone'], 'auto');
    });

    test('obtiene y convierte la calidad del aire', () async {
      final service = AirQualityService(
        _client((_) async => jsonResponse(sampleAirQualityJson(aqi: 55))),
      );
      final data = await service.fetchAirQuality(latitude: -0.23, longitude: -78.52);

      expect(data.current!.usAqi, 55);
      expect(data.hourly, hasLength(48));
    });
  });

  group('GeocodingService', () {
    test('devuelve las ciudades y omite los resultados incompletos', () async {
      late Uri requested;
      final service = GeocodingService(_client((request) async {
        requested = request.url;
        return jsonResponse(sampleGeocodingJson());
      }));

      final cities = await service.searchCities('  Bogota ');

      expect(requested.host, 'geocoding-api.open-meteo.com');
      expect(requested.queryParameters['name'], 'Bogota');
      expect(requested.queryParameters['language'], 'es');
      expect(cities, hasLength(1));
      expect(cities.single.name, 'Bogotá');
      expect(cities.single.region, 'Bogotá D.C.');
      expect(cities.single.country, 'Colombia');
      expect(cities.single.latitude, closeTo(4.60971, 1e-9));
      expect(cities.single.subtitle, 'Bogotá D.C., Colombia');
    });

    test('una búsqueda sin resultados devuelve una lista vacía', () async {
      final service = GeocodingService(
        _client((_) async => jsonResponse({'generationtime_ms': 0.4})),
      );
      expect(await service.searchCities('zzzzzzzz'), isEmpty);
    });

    test('no consulta la API con menos de dos caracteres', () async {
      var calls = 0;
      final service = GeocodingService(_client((_) async {
        calls++;
        return jsonResponse({});
      }));

      expect(await service.searchCities('a'), isEmpty);
      expect(await service.searchCities('  '), isEmpty);
      expect(calls, 0);
    });

    test('un formato inesperado lanza UnexpectedResponseException', () async {
      final service = GeocodingService(
        _client((_) async => jsonResponse({'results': 'texto'})),
      );
      expect(service.searchCities('Quito'), throwsA(isA<UnexpectedResponseException>()));
    });
  });

  group('OverpassService', () {
    OverpassService serviceWith(
      Future<http.Response> Function(http.Request) handler, {
      List<String>? endpoints,
    }) {
      return OverpassService(
        _client(handler),
        endpoints: endpoints ??
            ['https://uno.test/api/interpreter', 'https://dos.test/api/interpreter'],
      );
    }

    test('buildQuery incluye el radio, las coordenadas y los selectores', () {
      final query = OverpassService.buildQuery(
        activity: ActivityType.cycling,
        latitude: -0.22985,
        longitude: -78.52495,
        radiusMeters: 5000,
      );

      expect(query, startsWith('[out:json]'));
      expect(query, contains('nwr(around:5000,-0.22985,-78.52495)'));
      expect(query, contains('"highway"="cycleway"'));
      expect(query, contains('"route"~"^(bicycle|mtb)\$"'));
      expect(query, contains('out center tags'));

      final walking = OverpassService.buildQuery(
        activity: ActivityType.walking,
        latitude: 0,
        longitude: 0,
        radiusMeters: 2000,
      );
      expect(walking, contains('park|garden|nature_reserve'));
      expect(walking, isNot(contains('cycleway')));
    });

    test('parsePlaces convierte los elementos y calcula distancias', () {
      final service = serviceWith((_) async => jsonResponse({}));
      final places = service.parsePlaces(
        sampleOverpassJson(),
        originLatitude: -0.23,
        originLongitude: -78.52,
      );

      // El elemento sin coordenadas se omite.
      expect(places, hasLength(5));
      final byId = {for (final place in places) place.id: place};

      final cycleway = byId['way/101']!;
      expect(cycleway.kind, PlaceKind.cycleway);
      expect(cycleway.name, 'Ciclovía Norte');
      expect(cycleway.latitude, -0.2250);
      expect(cycleway.tags['lit'], 'yes');
      expect(cycleway.distanceMeters, greaterThan(0));

      expect(byId['node/102']!.kind, PlaceKind.park);
      expect(byId['relation/103']!.kind, PlaceKind.bicycleRoute);
      expect(byId['way/106']!.kind, PlaceKind.athleticsTrack);
      expect(byId['node/105']!.kind, PlaceKind.other);
      expect(byId['node/105']!.name, isNull);
      expect(byId['node/105']!.displayName, contains('sin nombre'));
    });

    test('searchNearby envía la consulta por POST y devuelve los lugares', () async {
      late http.Request sent;
      final service = serviceWith((request) async {
        sent = request;
        return jsonResponse(sampleOverpassJson());
      });

      final places = await service.searchNearby(
        activity: ActivityType.cycling,
        latitude: -0.23,
        longitude: -78.52,
        radiusMeters: 3000,
      );

      expect(sent.method, 'POST');
      expect(sent.url.host, 'uno.test');
      expect(sent.bodyFields['data'], contains('around:3000'));
      expect(places, isNotEmpty);
    });

    test('si la primera instancia está saturada usa la siguiente', () async {
      final hosts = <String>[];
      final service = serviceWith((request) async {
        hosts.add(request.url.host);
        if (request.url.host == 'uno.test') return http.Response('', 504);
        return jsonResponse(sampleOverpassJson());
      });

      final places = await service.searchNearby(
        activity: ActivityType.walking,
        latitude: -0.23,
        longitude: -78.52,
      );

      expect(hosts, ['uno.test', 'dos.test']);
      expect(places, isNotEmpty);
    });

    test('si todas las instancias fallan lanza el último error', () async {
      final service = serviceWith((_) async => http.Response('', 504));
      expect(
        service.searchNearby(
          activity: ActivityType.walking,
          latitude: 0,
          longitude: 0,
        ),
        throwsA(isA<ServiceUnavailableException>()),
      );
    });

    test('sin conexión no reintenta con otra instancia', () async {
      var calls = 0;
      final service = serviceWith((_) async {
        calls++;
        throw http.ClientException('sin red');
      });

      await expectLater(
        service.searchNearby(activity: ActivityType.walking, latitude: 0, longitude: 0),
        throwsA(isA<NoConnectionException>()),
      );
      expect(calls, 1);
    });

    test('un "remark" de error de ejecución se trata como servicio saturado', () async {
      final service = serviceWith(
        (_) async => jsonResponse({
          'elements': <Object>[],
          'remark': 'runtime error: Query timed out in "query" at line 3',
        }),
      );
      await expectLater(
        service.searchNearby(activity: ActivityType.walking, latitude: 0, longitude: 0),
        throwsA(isA<ServiceUnavailableException>()),
      );
    });

    test('una respuesta sin "elements" lanza UnexpectedResponseException', () async {
      final service = serviceWith((_) async => jsonResponse({'version': 0.6}));
      await expectLater(
        service.searchNearby(activity: ActivityType.walking, latitude: 0, longitude: 0),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('una zona sin lugares devuelve una lista vacía', () async {
      final service = serviceWith(
        (_) async => jsonResponse({'elements': <Object>[]}),
      );
      final places = await service.searchNearby(
        activity: ActivityType.walking,
        latitude: 0,
        longitude: 0,
      );
      expect(places, isEmpty);
    });
  });

  test('los lugares se pueden guardar y recuperar como JSON', () {
    const place = OutdoorPlace(
      osmType: 'way',
      osmId: 7,
      kind: PlaceKind.cycleway,
      latitude: -0.2,
      longitude: -78.5,
      name: 'Ciclovía',
      tags: {'bicycle': 'designated'},
    );

    final restored =
        OutdoorPlace.fromJson(jsonDecode(jsonEncode(place.toJson())) as Map<String, dynamic>);

    expect(restored.id, 'way/7');
    expect(restored.kind, PlaceKind.cycleway);
    expect(restored.name, 'Ciclovía');
    expect(restored.tags['bicycle'], 'designated');
    expect(restored.latitude, -0.2);
  });
}
