import 'weather_forecast.dart';

/// Factores que intervienen en la puntuación de un horario.
enum ScoreFactor {
  temperature('Temperatura'),
  rain('Lluvia'),
  wind('Viento'),
  uv('Índice UV'),
  airQuality('Calidad del aire');

  const ScoreFactor(this.label);

  final String label;
}

/// Categoría cualitativa de una puntuación (0 a 100).
enum ScoreCategory {
  excellent('Excelente'),
  good('Bueno'),
  caution('Precaución'),
  poor('Poco recomendable');

  const ScoreCategory(this.label);

  final String label;
}

/// Valoración cualitativa de un único factor.
enum FactorVerdict { good, fair, poor }

/// Resultado de evaluar un factor en una hora concreta.
class FactorResult {
  const FactorResult({
    required this.factor,
    required this.score,
    required this.weight,
    required this.verdict,
    required this.phrase,
    this.value,
    this.secondaryValue,
  });

  final ScoreFactor factor;

  /// Subpuntuación del factor (0 a 100).
  final double score;

  /// Peso efectivo del factor (suma 1 entre los factores disponibles).
  final double weight;

  final FactorVerdict verdict;

  /// Descripción breve, por ejemplo "viento suave" o "calor intenso".
  final String phrase;

  /// Valor medido: °C (temperatura), % (lluvia), km/h (viento), índice UV
  /// o US AQI, según el factor. Siempre en unidades métricas.
  final double? value;

  /// Valor secundario: milímetros de lluvia para el factor `rain`.
  final double? secondaryValue;
}

/// Evaluación completa de una hora para una actividad.
class HourRecommendation {
  const HourRecommendation({
    required this.time,
    required this.score,
    required this.category,
    required this.factors,
    required this.notes,
    required this.summary,
    required this.weather,
    this.usAqi,
    this.missingFactors = const [],
  });

  /// Inicio de la hora (hora local de la ubicación).
  final DateTime time;
  final int score;
  final ScoreCategory category;
  final List<FactorResult> factors;

  /// Avisos que explican límites aplicados (lluvia intensa, mala calidad del
  /// aire, poca luz, datos faltantes...).
  final List<String> notes;

  /// Explicación en lenguaje natural de la puntuación.
  final String summary;

  final HourlyWeather weather;
  final double? usAqi;

  /// Factores sin dato que no pudieron evaluarse.
  final List<ScoreFactor> missingFactors;
}

/// Franja de varias horas consecutivas.
class ScoreWindow {
  const ScoreWindow({
    required this.start,
    required this.end,
    required this.averageScore,
    required this.category,
  });

  final DateTime start;

  /// Fin de la franja (exclusivo).
  final DateTime end;
  final int averageScore;
  final ScoreCategory category;
}

/// Recomendaciones de un día completo para una actividad.
class DayRecommendation {
  const DayRecommendation({
    required this.date,
    required this.hours,
    this.bestHour,
    this.bestWindow,
    this.averageScore,
  });

  final DateTime date;

  /// Horas evaluadas, en orden cronológico.
  final List<HourRecommendation> hours;
  final HourRecommendation? bestHour;
  final ScoreWindow? bestWindow;
  final int? averageScore;

  bool get isEmpty => hours.isEmpty;
}
