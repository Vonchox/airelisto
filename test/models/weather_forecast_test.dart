import 'package:aire_listo/core/errors/app_exceptions.dart';
import 'package:aire_listo/models/weather_forecast.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';

void main() {
  group('WeatherForecast.fromJson', () {
    test('convierte la respuesta de Open-Meteo en modelos Dart', () {
      final forecast = WeatherForecast.fromJson(sampleWeatherJson());

      expect(forecast.timezone, 'America/Guayaquil');
      expect(forecast.utcOffsetSeconds, -18000);
      expect(forecast.hourly, hasLength(48));
      expect(forecast.daily, hasLength(2));

      final current = forecast.current!;
      expect(current.temperature, 19.5);
      expect(current.apparentTemperature, 19.0);
      expect(current.relativeHumidity, 70);
      expect(current.weatherCode, 2);
      expect(current.isDay, isTrue);

      final firstHour = forecast.hourly.first;
      expect(firstHour.time, DateTime.utc(2026, 11, 10, 0));
      expect(firstHour.temperature, 21);
      expect(firstHour.apparentTemperature, 20);
      expect(firstHour.precipitationProbability, 5);
      expect(firstHour.windSpeed, 8);
      expect(firstHour.uvIndex, 2);

      final firstDay = forecast.daily.first;
      expect(firstDay.date, DateTime.utc(2026, 11, 10));
      expect(firstDay.temperatureMax, 22.4);
      expect(firstDay.temperatureMin, 10.1);
      expect(firstDay.precipitationProbabilityMax, 40);
      expect(firstDay.uvIndexMax, 9.5);
      expect(firstDay.sunrise, DateTime.utc(2026, 11, 10, 6, 8));
      expect(firstDay.sunset, DateTime.utc(2026, 11, 10, 18, 10));
    });

    test('hoursOfDay, hourAt y dailyFor filtran por fecha', () {
      final forecast = WeatherForecast.fromJson(sampleWeatherJson());

      expect(forecast.hoursOfDay(DateTime.utc(2026, 11, 11)), hasLength(24));
      expect(forecast.hoursOfDay(DateTime.utc(2026, 11, 20)), isEmpty);
      expect(forecast.hourAt(DateTime.utc(2026, 11, 11, 15, 30))?.time,
          DateTime.utc(2026, 11, 11, 15));
      expect(forecast.hourAt(DateTime.utc(2026, 12, 1, 1)), isNull);
      expect(forecast.dailyFor(DateTime.utc(2026, 11, 11))?.date,
          DateTime.utc(2026, 11, 11));
    });

    test('nowAtLocation aplica el desfase horario de la ubicación', () {
      final forecast = WeatherForecast.fromJson(sampleWeatherJson());
      final now = forecast.nowAtLocation(now: DateTime.utc(2026, 11, 10, 14, 0));
      expect(now, DateTime.utc(2026, 11, 10, 9, 0));
    });

    test('los valores nulos de una serie quedan como datos ausentes', () {
      final json = sampleWeatherJson();
      (json['hourly'] as Map<String, dynamic>)['temperature_2m'] =
          List<num?>.filled(48, 18)..[3] = null;

      final forecast = WeatherForecast.fromJson(json);

      expect(forecast.hourly[3].temperature, isNull);
      expect(forecast.hourly[4].temperature, 18);
    });

    test('informa las variables incompletas', () {
      final forecast =
          WeatherForecast.fromJson(sampleWeatherJson(includeUv: false));

      expect(forecast.incompleteVariables, contains('índice UV'));
      expect(forecast.incompleteVariables, isNot(contains('viento')));
      expect(WeatherForecast.fromJson(sampleWeatherJson()).incompleteVariables,
          isEmpty);
    });

    test('lanza UnexpectedResponseException si falta la sección hourly', () {
      final json = sampleWeatherJson()..remove('hourly');

      expect(
        () => WeatherForecast.fromJson(json),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('lanza UnexpectedResponseException si no hay horas', () {
      final json = sampleWeatherJson();
      json['hourly'] = {'time': <String>[]};

      expect(
        () => WeatherForecast.fromJson(json),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('rechaza fechas con formato inesperado', () {
      final json = sampleWeatherJson();
      (json['hourly'] as Map<String, dynamic>)['time'] =
          List<String>.filled(48, 'no-es-una-fecha');

      expect(
        () => WeatherForecast.fromJson(json),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });
  });
}
