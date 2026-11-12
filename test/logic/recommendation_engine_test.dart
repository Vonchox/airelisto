import 'package:aire_listo/logic/recommendation_engine.dart';
import 'package:aire_listo/logic/scoring_config.dart';
import 'package:aire_listo/models/activity_type.dart';
import 'package:aire_listo/models/air_quality.dart';
import 'package:aire_listo/models/recommendation.dart';
import 'package:aire_listo/models/weather_forecast.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';

/// Hora con condiciones ideales para las tres actividades (15 °C cae dentro
/// del rango ideal de caminar, correr y bicicleta).
HourlyWeather _hour({
  int hour = 10,
  double? apparent = 15,
  double? rainProbability = 5,
  double? rain = 0,
  double? wind = 8,
  double? uv = 2,
}) {
  return HourlyWeather(
    time: DateTime.utc(2026, 11, 10, hour),
    temperature: apparent,
    apparentTemperature: apparent,
    precipitationProbability: rainProbability,
    precipitation: rain,
    windSpeed: wind,
    uvIndex: uv,
  );
}

void main() {
  final engine = RecommendationEngine();
  final sunrise = DateTime.utc(2026, 11, 10, 6, 8);
  final sunset = DateTime.utc(2026, 11, 10, 18, 10);

  HourRecommendation evaluate(
    ActivityType activity,
    HourlyWeather hour, {
    double? aqi = 30,
  }) {
    final result = engine.evaluateHour(
      activity: activity,
      hour: hour,
      usAqi: aqi,
      sunrise: sunrise,
      sunset: sunset,
    );
    expect(result, isNotNull);
    return result!;
  }

  group('Configuración', () {
    test('los pesos de cada actividad suman 1', () {
      for (final activity in ActivityType.values) {
        final profile = ScoringConfig.standard.profileFor(activity);
        final total = ScoreFactor.values
            .fold<double>(0, (sum, factor) => sum + profile.weightOf(factor));
        expect(total, closeTo(1.0, 1e-9), reason: activity.id);
      }
    });

    test('los pesos reflejan la prioridad de cada actividad', () {
      final config = ScoringConfig.standard;
      final run = config.profileFor(ActivityType.running);
      final bike = config.profileFor(ActivityType.cycling);
      final walk = config.profileFor(ActivityType.walking);

      // Correr: temperatura, aire y lluvia son los tres factores principales.
      expect(run.weightOf(ScoreFactor.airQuality),
          greaterThan(run.weightOf(ScoreFactor.wind)));
      expect(run.weightOf(ScoreFactor.temperature),
          greaterThan(run.weightOf(ScoreFactor.uv)));
      // Bicicleta: el viento es el factor más pesado.
      expect(bike.weightOf(ScoreFactor.wind),
          greaterThan(bike.weightOf(ScoreFactor.temperature)));
      // Caminar: temperatura, lluvia y UV pesan más que el viento.
      expect(walk.weightOf(ScoreFactor.uv),
          greaterThan(walk.weightOf(ScoreFactor.wind)));
    });

    test('las curvas devuelven 0, 100 y valores intermedios', () {
      const range = RangeCurve(lowerLimit: 0, idealMin: 10, idealMax: 20, upperLimit: 40);
      expect(range.score(15), 100);
      expect(range.score(10), 100);
      expect(range.score(5), closeTo(50, 1e-9));
      expect(range.score(-3), 0);
      expect(range.score(30), closeTo(50, 1e-9));
      expect(range.score(45), 0);

      const upper = UpperLimitCurve(idealMax: 10, limit: 60);
      expect(upper.score(5), 100);
      expect(upper.score(35), closeTo(50, 1e-9));
      expect(upper.score(80), 0);
    });
  });

  group('Clasificación de puntuaciones', () {
    test('los límites de categoría son 80 / 60 / 40', () {
      final config = ScoringConfig.standard;
      expect(config.categoryFor(100), ScoreCategory.excellent);
      expect(config.categoryFor(80), ScoreCategory.excellent);
      expect(config.categoryFor(79), ScoreCategory.good);
      expect(config.categoryFor(60), ScoreCategory.good);
      expect(config.categoryFor(59), ScoreCategory.caution);
      expect(config.categoryFor(40), ScoreCategory.caution);
      expect(config.categoryFor(39), ScoreCategory.poor);
      expect(config.categoryFor(0), ScoreCategory.poor);
    });
  });

  group('evaluateHour', () {
    test('condiciones ideales dan 100 y categoría Excelente', () {
      for (final activity in ActivityType.values) {
        final result = evaluate(activity, _hour());
        expect(result.score, 100, reason: activity.id);
        expect(result.category, ScoreCategory.excellent);
        expect(result.factors, hasLength(5));
        expect(result.notes, isEmpty);
        expect(result.summary, startsWith('Buen momento para ${activity.verb}'));
      }
    });

    test('probabilidad de lluvia muy alta limita la puntuación a Poco recomendable', () {
      final result = evaluate(
        ActivityType.walking,
        _hour(rainProbability: 90, rain: 0.2),
      );

      expect(result.score, lessThanOrEqualTo(39));
      expect(result.category, ScoreCategory.poor);
      expect(result.notes, contains('Probabilidad de lluvia muy alta.'));
      expect(result.summary, startsWith('No es el mejor momento'));
    });

    test('lluvia intensa también aplica un tope', () {
      final result = evaluate(ActivityType.cycling, _hour(rain: 6));
      expect(result.score, lessThanOrEqualTo(39));
      expect(result.notes, contains('Se prevé lluvia intensa.'));
    });

    test('el viento penaliza más a ciclismo que a caminar', () {
      final hour = _hour(wind: 30);
      final walking = evaluate(ActivityType.walking, hour);
      final cycling = evaluate(ActivityType.cycling, hour);

      expect(walking.score, inInclusiveRange(97, 98));
      expect(cycling.score, 81);
      expect(walking.score, greaterThan(cycling.score));
    });

    test('viento muy fuerte limita a ciclismo pero no a caminar', () {
      final hour = _hour(wind: 50);
      final cycling = evaluate(ActivityType.cycling, hour);
      final walking = evaluate(ActivityType.walking, hour);

      expect(cycling.score, lessThanOrEqualTo(39));
      expect(cycling.notes, contains('Viento muy fuerte para ir en bicicleta.'));
      expect(walking.score, greaterThan(60));
    });

    test('la mala calidad del aire pesa más al correr y limita la categoría', () {
      final result = evaluate(ActivityType.running, _hour(), aqi: 120);

      expect(result.score, 59);
      expect(result.category, ScoreCategory.caution);
      expect(
        result.notes,
        contains('Calidad del aire dañina para grupos sensibles (US AQI 101 o más).'),
      );

      final walking = evaluate(ActivityType.walking, _hour(), aqi: 120);
      // Al caminar el AQI pesa menos y la curva es más tolerante,
      // pero el tope de grupos sensibles se aplica igualmente.
      expect(walking.score, lessThanOrEqualTo(59));
    });

    test('aire dañino (AQI >= 151) da Poco recomendable', () {
      final result = evaluate(ActivityType.running, _hour(), aqi: 160);
      expect(result.category, ScoreCategory.poor);
    });

    test('calor extremo limita la puntuación', () {
      final result = evaluate(ActivityType.walking, _hour(apparent: 37));
      expect(result.category, ScoreCategory.poor);
      expect(result.notes, contains('Sensación térmica extrema por calor.'));
    });

    test('la temperatura ideal depende de la actividad', () {
      // 8 °C: ideal para correr (6–17), fresco para caminar (14–26).
      final running = evaluate(ActivityType.running, _hour(apparent: 8));
      final walking = evaluate(ActivityType.walking, _hour(apparent: 8));
      final tempRunning =
          running.factors.firstWhere((f) => f.factor == ScoreFactor.temperature);
      final tempWalking =
          walking.factors.firstWhere((f) => f.factor == ScoreFactor.temperature);

      expect(tempRunning.score, 100);
      expect(tempWalking.score, lessThan(60));
      expect(tempWalking.phrase, 'ambiente fresco');
    });

    test('de noche se resta una penalización', () {
      final result = evaluate(ActivityType.walking, _hour(hour: 2));

      expect(result.score, 80);
      expect(result.notes, contains('Es de noche o hay poca luz natural a esta hora.'));
    });

    test('sin datos de calidad del aire se reparte el peso entre los demás factores', () {
      final result = evaluate(ActivityType.running, _hour(), aqi: null);

      expect(result.score, 100);
      expect(result.missingFactors, [ScoreFactor.airQuality]);
      expect(result.factors.any((f) => f.factor == ScoreFactor.airQuality), isFalse);
      final totalWeight = result.factors.fold<double>(0, (sum, f) => sum + f.weight);
      expect(totalWeight, closeTo(1.0, 1e-9));
      expect(result.notes.single, startsWith('Sin datos de calidad del aire'));
    });

    test('devuelve null si los datos disponibles no alcanzan', () {
      final result = engine.evaluateHour(
        activity: ActivityType.walking,
        hour: _hour(apparent: null, rainProbability: null, rain: null, uv: null),
      );
      // Solo hay viento (10 % del peso): no se puntúa.
      expect(result, isNull);
    });

    test('los factores quedan ordenados por peso', () {
      final result = evaluate(ActivityType.cycling, _hour());
      expect(result.factors.first.factor, ScoreFactor.wind);
      for (var i = 1; i < result.factors.length; i++) {
        expect(result.factors[i - 1].weight,
            greaterThanOrEqualTo(result.factors[i].weight));
      }
    });
  });

  group('recommendDay', () {
    final weather = WeatherForecast.fromJson(sampleWeatherJson());
    final date = DateTime.utc(2026, 11, 10);

    test('evalúa solo las horas activas y elige la mejor franja', () {
      final result = engine.recommendDay(
        activity: ActivityType.walking,
        weather: weather,
        date: date,
      );

      // Horas 5 a 21 inclusive.
      expect(result.hours, hasLength(17));
      expect(result.hours.first.time, DateTime.utc(2026, 11, 10, 5));
      expect(result.hours.last.time, DateTime.utc(2026, 11, 10, 21));
      // La hora 5 (antes del amanecer) tiene penalización nocturna.
      expect(result.hours.first.score, 80);
      expect(result.bestHour!.score, 100);
      expect(result.bestWindow!.start, DateTime.utc(2026, 11, 10, 6));
      expect(result.bestWindow!.end, DateTime.utc(2026, 11, 10, 8));
      expect(result.bestWindow!.averageScore, 100);
      expect(result.bestWindow!.category, ScoreCategory.excellent);
      expect(result.averageScore, inInclusiveRange(90, 100));
    });

    test('notBefore descarta las horas pasadas', () {
      final result = engine.recommendDay(
        activity: ActivityType.walking,
        weather: weather,
        date: date,
        notBefore: DateTime.utc(2026, 11, 10, 15),
      );

      expect(result.hours.first.time, DateTime.utc(2026, 11, 10, 15));
      expect(result.hours, hasLength(7));
    });

    test('usa la calidad del aire de cada hora', () {
      final air = AirQualityData.fromJson(sampleAirQualityJson(aqi: 160));
      final result = engine.recommendDay(
        activity: ActivityType.running,
        weather: weather,
        airQuality: air,
        date: date,
      );

      expect(result.hours.every((h) => h.category == ScoreCategory.poor), isTrue);
      expect(result.hours.first.usAqi, 160);
    });

    test('una fecha sin datos devuelve un resultado vacío', () {
      final result = engine.recommendDay(
        activity: ActivityType.walking,
        weather: weather,
        date: DateTime.utc(2026, 12, 25),
      );

      expect(result.isEmpty, isTrue);
      expect(result.bestHour, isNull);
      expect(result.bestWindow, isNull);
    });

    test('si no hay horas consecutivas usa la mejor hora como franja', () {
      final shortConfig = ScoringConfig(
        profiles: ScoringConfig.standard.profiles,
        windowHours: 2,
      );
      final shortEngine = RecommendationEngine(config: shortConfig);
      final result = shortEngine.recommendDay(
        activity: ActivityType.walking,
        weather: weather,
        date: date,
        notBefore: DateTime.utc(2026, 11, 10, 21),
      );

      expect(result.hours, hasLength(1));
      expect(result.bestWindow!.start, DateTime.utc(2026, 11, 10, 21));
      expect(result.bestWindow!.end, DateTime.utc(2026, 11, 10, 22));
    });
  });
}
