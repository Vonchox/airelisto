import 'dart:math' as math;

import '../models/activity_type.dart';
import '../models/air_quality.dart';
import '../models/recommendation.dart';
import '../models/weather_forecast.dart';
import 'scoring_config.dart';

/// Algoritmo propio de puntuación de horarios.
///
/// Para cada hora se calcula una puntuación de 0 a 100:
///
/// 1. Cada variable (temperatura, lluvia, viento, UV y calidad del aire) se
///    convierte en una subpuntuación de 0 a 100 mediante una curva lineal por
///    tramos definida en [ScoringConfig].
/// 2. Las subpuntuaciones se combinan con un promedio ponderado. Los pesos
///    dependen de la actividad. Si falta algún dato, su peso se reparte entre
///    los factores disponibles (siempre que cubran al menos la mitad del peso).
/// 3. Se resta una penalización si es de noche o hay poca luz natural.
/// 4. Los "límites duros" (lluvia muy probable, aire dañino, calor extremo,
///    viento fuerte en bicicleta...) imponen un tope a la puntuación.
/// 5. La puntuación final se clasifica en Excelente / Bueno / Precaución /
///    Poco recomendable.
///
/// La puntuación es una **orientación** basada en pronósticos; no garantiza
/// seguridad ni sustituye el criterio personal o el consejo médico.
class RecommendationEngine {
  RecommendationEngine({ScoringConfig? config})
      : config = config ?? ScoringConfig.standard;

  final ScoringConfig config;

  /// Evalúa una hora para una actividad. Devuelve `null` si no hay datos
  /// suficientes para puntuar.
  HourRecommendation? evaluateHour({
    required ActivityType activity,
    required HourlyWeather hour,
    double? usAqi,
    DateTime? sunrise,
    DateTime? sunset,
  }) {
    final profile = config.profileFor(activity);
    final raw = <_RawFactor>[];

    final apparent = hour.apparentTemperature ?? hour.temperature;
    if (apparent != null) {
      final score = profile.temperature.score(apparent);
      raw.add(_RawFactor(
        factor: ScoreFactor.temperature,
        score: score,
        value: apparent,
        phrase: _temperaturePhrase(profile.temperature, apparent, score),
      ));
    }

    final probability = hour.precipitationProbability;
    final amount = hour.precipitation;
    if (probability != null || amount != null) {
      final probabilityScore =
          probability == null ? null : profile.rainProbability.score(probability);
      final amountScore = amount == null ? null : profile.rainAmount.score(amount);
      final double score;
      if (probabilityScore != null && amountScore != null) {
        score = profile.rainProbabilityShare * probabilityScore +
            (1 - profile.rainProbabilityShare) * amountScore;
      } else {
        score = (probabilityScore ?? amountScore)!;
      }
      raw.add(_RawFactor(
        factor: ScoreFactor.rain,
        score: score,
        value: probability,
        secondaryValue: amount,
        phrase: _rainPhrase(score),
      ));
    }

    final wind = hour.windSpeed;
    if (wind != null) {
      final score = profile.wind.score(wind);
      raw.add(_RawFactor(
        factor: ScoreFactor.wind,
        score: score,
        value: wind,
        phrase: _windPhrase(score),
      ));
    }

    final uv = hour.uvIndex;
    if (uv != null) {
      raw.add(_RawFactor(
        factor: ScoreFactor.uv,
        score: profile.uv.score(uv),
        value: uv,
        phrase: _uvPhrase(uv),
      ));
    }

    if (usAqi != null) {
      raw.add(_RawFactor(
        factor: ScoreFactor.airQuality,
        score: profile.airQuality.score(usAqi),
        value: usAqi,
        phrase: _airPhrase(usAqi),
      ));
    }

    final weightSum = raw.fold<double>(
      0,
      (sum, item) => sum + profile.weightOf(item.factor),
    );
    if (raw.isEmpty || weightSum < config.minimumWeightCoverage) return null;

    final weighted = raw.fold<double>(
          0,
          (sum, item) => sum + item.score * profile.weightOf(item.factor),
        ) /
        weightSum;

    final factors = raw
        .map(
          (item) => FactorResult(
            factor: item.factor,
            score: item.score,
            weight: profile.weightOf(item.factor) / weightSum,
            verdict: config.verdictFor(item.score),
            phrase: item.phrase,
            value: item.value,
            secondaryValue: item.secondaryValue,
          ),
        )
        .toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));

    final notes = <String>[];
    var score = weighted;

    if (_isDark(hour.time, sunrise, sunset)) {
      score -= config.nightPenalty;
      notes.add('Es de noche o hay poca luz natural a esta hora.');
    }

    var cap = 100;
    for (final limit in profile.hardLimits) {
      final value = _metricValue(limit.metric, hour, apparent, usAqi);
      if (value == null || !limit.isTriggeredBy(value)) continue;
      cap = math.min(cap, limit.maxScore);
      if (!notes.contains(limit.message)) notes.add(limit.message);
    }

    final missing = ScoreFactor.values
        .where((factor) => !raw.any((item) => item.factor == factor))
        .where((factor) => profile.weightOf(factor) > 0)
        .toList();
    if (missing.isNotEmpty) {
      final names = missing.map((f) => f.label.toLowerCase()).join(', ');
      notes.add('Sin datos de $names: la puntuación usa solo la información disponible.');
    }

    final bounded = math.max(0.0, math.min(100.0, score));
    final finalScore = math.min(cap, bounded.round());
    final category = config.categoryFor(finalScore);

    return HourRecommendation(
      time: hour.time,
      score: finalScore,
      category: category,
      factors: factors,
      notes: notes,
      summary: _summary(activity, category, factors, notes),
      weather: hour,
      usAqi: usAqi,
      missingFactors: missing,
    );
  }

  /// Evalúa las horas de un día y obtiene la mejor hora y la mejor franja.
  ///
  /// Si se indica [notBefore], solo se consideran las horas a partir de ese
  /// instante (útil para "lo que queda de hoy").
  DayRecommendation recommendDay({
    required ActivityType activity,
    required WeatherForecast weather,
    AirQualityData? airQuality,
    required DateTime date,
    DateTime? notBefore,
  }) {
    final daily = weather.dailyFor(date);
    final hours = <HourRecommendation>[];

    for (final hour in weather.hoursOfDay(date)) {
      if (hour.time.hour < config.firstHour || hour.time.hour > config.lastHour) {
        continue;
      }
      if (notBefore != null && hour.time.isBefore(notBefore)) continue;

      final result = evaluateHour(
        activity: activity,
        hour: hour,
        usAqi: airQuality?.hourAt(hour.time)?.usAqi,
        sunrise: daily?.sunrise,
        sunset: daily?.sunset,
      );
      if (result != null) hours.add(result);
    }

    if (hours.isEmpty) return DayRecommendation(date: date, hours: const []);

    var bestHour = hours.first;
    for (final hour in hours) {
      if (hour.score > bestHour.score) bestHour = hour;
    }

    final average =
        (hours.fold<int>(0, (sum, h) => sum + h.score) / hours.length).round();

    return DayRecommendation(
      date: date,
      hours: hours,
      bestHour: bestHour,
      bestWindow: _bestWindow(hours, bestHour),
      averageScore: average,
    );
  }

  /// Mejor franja de [ScoringConfig.windowHours] horas consecutivas. Si no hay
  /// horas consecutivas suficientes, devuelve la mejor hora individual.
  ScoreWindow _bestWindow(List<HourRecommendation> hours, HourRecommendation best) {
    final size = config.windowHours;
    ScoreWindow? result;

    for (var i = 0; i + size <= hours.length; i++) {
      var consecutive = true;
      for (var k = 1; k < size; k++) {
        final expected = hours[i].time.add(Duration(hours: k));
        if (hours[i + k].time != expected) {
          consecutive = false;
          break;
        }
      }
      if (!consecutive) continue;

      var total = 0;
      for (var k = 0; k < size; k++) {
        total += hours[i + k].score;
      }
      final average = (total / size).round();
      if (result == null || average > result.averageScore) {
        result = ScoreWindow(
          start: hours[i].time,
          end: hours[i].time.add(Duration(hours: size)),
          averageScore: average,
          category: config.categoryFor(average),
        );
      }
    }

    return result ??
        ScoreWindow(
          start: best.time,
          end: best.time.add(const Duration(hours: 1)),
          averageScore: best.score,
          category: best.category,
        );
  }

  // ---------------------------------------------------------------------------
  // Utilidades internas
  // ---------------------------------------------------------------------------

  bool _isDark(DateTime time, DateTime? sunrise, DateTime? sunset) {
    final end = time.add(const Duration(hours: 1));
    if (sunrise != null && !end.isAfter(sunrise)) return true;
    if (sunset != null && !time.isBefore(sunset)) return true;
    return false;
  }

  double? _metricValue(
    LimitMetric metric,
    HourlyWeather hour,
    double? apparent,
    double? usAqi,
  ) {
    switch (metric) {
      case LimitMetric.apparentTemperature:
        return apparent;
      case LimitMetric.precipitationProbability:
        return hour.precipitationProbability;
      case LimitMetric.precipitationAmount:
        return hour.precipitation;
      case LimitMetric.windSpeed:
        return hour.windSpeed;
      case LimitMetric.uvIndex:
        return hour.uvIndex;
      case LimitMetric.usAqi:
        return usAqi;
    }
  }

  String _temperaturePhrase(RangeCurve curve, double value, double score) {
    if (score >= config.goodFactorMin) return 'temperatura agradable';
    if (value < curve.idealMin) {
      return score < 25 ? 'frío intenso' : 'ambiente fresco';
    }
    return score < 25 ? 'calor intenso' : 'ambiente caluroso';
  }

  String _rainPhrase(double score) {
    if (score >= config.goodFactorMin) return 'baja probabilidad de lluvia';
    if (score >= config.poorFactorMax) return 'posibilidad de lluvia';
    return 'lluvia probable';
  }

  String _windPhrase(double score) {
    if (score >= config.goodFactorMin) return 'viento suave';
    if (score >= config.poorFactorMax) return 'viento moderado';
    return 'viento fuerte';
  }

  String _uvPhrase(double uv) {
    if (uv < 3) return 'índice UV bajo';
    if (uv < 6) return 'índice UV moderado';
    if (uv < 8) return 'índice UV alto';
    if (uv < 11) return 'índice UV muy alto';
    return 'índice UV extremo';
  }

  String _airPhrase(double usAqi) {
    final category = AqiCategory.fromUsAqi(usAqi);
    if (category == null) return 'calidad del aire sin datos';
    return 'calidad del aire ${category.label.toLowerCase()}';
  }

  String _summary(
    ActivityType activity,
    ScoreCategory category,
    List<FactorResult> factors,
    List<String> notes,
  ) {
    final positives = factors
        .where((f) => f.verdict == FactorVerdict.good)
        .take(2)
        .map((f) => f.phrase)
        .toList();

    final concernFactors = factors
        .where((f) => f.verdict != FactorVerdict.good)
        .toList()
      ..sort(
        (a, b) => (b.weight * (100 - b.score)).compareTo(a.weight * (100 - a.score)),
      );
    final concerns = concernFactors.take(2).map((f) => f.phrase).toList();

    final buffer = StringBuffer();
    switch (category) {
      case ScoreCategory.excellent:
      case ScoreCategory.good:
        buffer.write('Buen momento para ${activity.verb}');
        if (positives.isNotEmpty) buffer.write(': ${_join(positives)}');
        buffer.write('.');
        if (concerns.isNotEmpty) buffer.write(' A tener en cuenta: ${_join(concerns)}.');
      case ScoreCategory.caution:
        buffer.write('Condiciones aceptables con reservas para ${activity.verb}.');
        if (concerns.isNotEmpty) buffer.write(' Pesa en contra: ${_join(concerns)}.');
        if (positives.isNotEmpty) buffer.write(' A favor: ${_join(positives)}.');
      case ScoreCategory.poor:
        buffer.write('No es el mejor momento para ${activity.verb}.');
        if (concerns.isNotEmpty) buffer.write(' Pesa en contra: ${_join(concerns)}.');
        if (concerns.isEmpty && notes.isNotEmpty) buffer.write(' ${notes.first}');
    }
    return buffer.toString();
  }

  String _join(List<String> items) {
    if (items.length <= 1) return items.join();
    if (items.length == 2) return '${items[0]} y ${items[1]}';
    return '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';
  }
}

class _RawFactor {
  const _RawFactor({
    required this.factor,
    required this.score,
    required this.phrase,
    this.value,
    this.secondaryValue,
  });

  final ScoreFactor factor;
  final double score;
  final String phrase;
  final double? value;
  final double? secondaryValue;
}
