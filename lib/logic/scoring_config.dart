import '../models/activity_type.dart';
import '../models/recommendation.dart';

/// Variable que puede activar un límite duro.
enum LimitMetric {
  apparentTemperature,
  precipitationProbability,
  precipitationAmount,
  windSpeed,
  uvIndex,
  usAqi,
}

/// Convierte el valor de una variable (temperatura, viento...) en una
/// subpuntuación de 0 a 100.
abstract class ScoreCurve {
  const ScoreCurve();

  double score(double value);
}

/// Curva para variables con un rango ideal (por ejemplo, la temperatura).
///
/// * Dentro de `[idealMin, idealMax]` vale 100.
/// * Baja linealmente hasta 0 en `lowerLimit` y en `upperLimit`.
class RangeCurve extends ScoreCurve {
  const RangeCurve({
    required this.lowerLimit,
    required this.idealMin,
    required this.idealMax,
    required this.upperLimit,
  });

  final double lowerLimit;
  final double idealMin;
  final double idealMax;
  final double upperLimit;

  @override
  double score(double value) {
    if (value >= idealMin && value <= idealMax) return 100;
    if (value < idealMin) {
      if (value <= lowerLimit) return 0;
      return 100 * (value - lowerLimit) / (idealMin - lowerLimit);
    }
    if (value >= upperLimit) return 0;
    return 100 * (upperLimit - value) / (upperLimit - idealMax);
  }
}

/// Curva para variables donde "menos es mejor" (lluvia, viento, UV, AQI).
///
/// Vale 100 hasta `idealMax` y baja linealmente hasta 0 en `limit`.
class UpperLimitCurve extends ScoreCurve {
  const UpperLimitCurve({required this.idealMax, required this.limit});

  final double idealMax;
  final double limit;

  @override
  double score(double value) {
    if (value <= idealMax) return 100;
    if (value >= limit) return 0;
    return 100 * (limit - value) / (limit - idealMax);
  }
}

/// Regla que limita la puntuación máxima cuando una variable es extrema.
///
/// Por ejemplo: con probabilidad de lluvia >= 80 % la puntuación no puede
/// superar 39 (“Poco recomendable”) aunque el resto de factores sea bueno.
class HardLimit {
  const HardLimit({
    required this.metric,
    required this.threshold,
    required this.maxScore,
    required this.message,
    this.whenAbove = true,
  });

  final LimitMetric metric;
  final double threshold;
  final int maxScore;
  final String message;

  /// `true`: se activa con valores >= umbral. `false`: con valores <= umbral.
  final bool whenAbove;

  bool isTriggeredBy(double value) =>
      whenAbove ? value >= threshold : value <= threshold;
}

/// Criterios de evaluación de una actividad: pesos, curvas y límites duros.
class ActivityProfile {
  const ActivityProfile({
    required this.activity,
    required this.weights,
    required this.temperature,
    required this.rainProbability,
    required this.rainAmount,
    required this.wind,
    required this.uv,
    required this.airQuality,
    required this.hardLimits,
    this.rainProbabilityShare = 0.6,
  });

  final ActivityType activity;

  /// Peso de cada factor. Deben sumar 1.
  final Map<ScoreFactor, double> weights;

  /// Curva sobre la sensación térmica (°C).
  final RangeCurve temperature;

  /// Curva sobre la probabilidad de precipitación (%).
  final UpperLimitCurve rainProbability;

  /// Curva sobre la precipitación horaria (mm).
  final UpperLimitCurve rainAmount;

  /// Curva sobre la velocidad del viento (km/h).
  final UpperLimitCurve wind;

  /// Curva sobre el índice UV.
  final UpperLimitCurve uv;

  /// Curva sobre el US AQI.
  final UpperLimitCurve airQuality;

  final List<HardLimit> hardLimits;

  /// Parte del factor lluvia que corresponde a la probabilidad (el resto es
  /// la cantidad prevista).
  final double rainProbabilityShare;

  double weightOf(ScoreFactor factor) => weights[factor] ?? 0;
}

/// Configuración central del algoritmo de recomendaciones.
///
/// Todos los pesos, umbrales y límites del sistema viven aquí; las pantallas
/// no contienen criterios de evaluación.
class ScoringConfig {
  const ScoringConfig({
    required this.profiles,
    this.excellentMin = 80,
    this.goodMin = 60,
    this.cautionMin = 40,
    this.goodFactorMin = 75,
    this.poorFactorMax = 45,
    this.firstHour = 5,
    this.lastHour = 21,
    this.windowHours = 2,
    this.nightPenalty = 20,
    this.minimumWeightCoverage = 0.5,
  });

  final Map<ActivityType, ActivityProfile> profiles;

  /// Puntuación mínima de cada categoría (80–100, 60–79, 40–59, 0–39).
  final int excellentMin;
  final int goodMin;
  final int cautionMin;

  /// Un factor se considera favorable con subpuntuación >= [goodFactorMin] y
  /// desfavorable con subpuntuación < [poorFactorMax].
  final int goodFactorMin;
  final int poorFactorMax;

  /// Primera y última hora de inicio que se evalúan en un día.
  final int firstHour;
  final int lastHour;

  /// Horas consecutivas de la "mejor franja" sugerida.
  final int windowHours;

  /// Puntos que se restan cuando es de noche o hay poca luz.
  final int nightPenalty;

  /// Fracción mínima del peso total que debe tener datos para puntuar.
  final double minimumWeightCoverage;

  ActivityProfile profileFor(ActivityType activity) => profiles[activity]!;

  ScoreCategory categoryFor(int score) {
    if (score >= excellentMin) return ScoreCategory.excellent;
    if (score >= goodMin) return ScoreCategory.good;
    if (score >= cautionMin) return ScoreCategory.caution;
    return ScoreCategory.poor;
  }

  FactorVerdict verdictFor(double factorScore) {
    if (factorScore >= goodFactorMin) return FactorVerdict.good;
    if (factorScore < poorFactorMax) return FactorVerdict.poor;
    return FactorVerdict.fair;
  }

  /// Configuración estándar de AireListo.
  static final ScoringConfig standard = ScoringConfig(
    profiles: {
      // CAMINAR: temperatura, lluvia e índice UV pesan más.
      ActivityType.walking: ActivityProfile(
        activity: ActivityType.walking,
        weights: const {
          ScoreFactor.temperature: 0.30,
          ScoreFactor.rain: 0.27,
          ScoreFactor.uv: 0.18,
          ScoreFactor.airQuality: 0.15,
          ScoreFactor.wind: 0.10,
        },
        temperature: const RangeCurve(
          lowerLimit: 0,
          idealMin: 14,
          idealMax: 26,
          upperLimit: 38,
        ),
        rainProbability: const UpperLimitCurve(idealMax: 10, limit: 70),
        rainAmount: const UpperLimitCurve(idealMax: 0, limit: 3),
        wind: const UpperLimitCurve(idealMax: 20, limit: 60),
        uv: const UpperLimitCurve(idealMax: 3, limit: 11),
        airQuality: const UpperLimitCurve(idealMax: 50, limit: 250),
        hardLimits: _commonLimits(),
      ),
      // CORRER: temperatura, calidad del aire y lluvia pesan más.
      ActivityType.running: ActivityProfile(
        activity: ActivityType.running,
        weights: const {
          ScoreFactor.temperature: 0.27,
          ScoreFactor.airQuality: 0.27,
          ScoreFactor.rain: 0.22,
          ScoreFactor.uv: 0.14,
          ScoreFactor.wind: 0.10,
        },
        temperature: const RangeCurve(
          lowerLimit: -5,
          idealMin: 6,
          idealMax: 17,
          upperLimit: 33,
        ),
        rainProbability: const UpperLimitCurve(idealMax: 10, limit: 65),
        rainAmount: const UpperLimitCurve(idealMax: 0, limit: 2.5),
        wind: const UpperLimitCurve(idealMax: 15, limit: 50),
        uv: const UpperLimitCurve(idealMax: 3, limit: 11),
        airQuality: const UpperLimitCurve(idealMax: 50, limit: 150),
        hardLimits: [
          ..._commonLimits(),
          const HardLimit(
            metric: LimitMetric.apparentTemperature,
            threshold: 32,
            maxScore: 59,
            message: 'Sensación térmica alta para un esfuerzo continuo.',
          ),
        ],
      ),
      // BICICLETA: viento, lluvia y temperatura pesan más.
      ActivityType.cycling: ActivityProfile(
        activity: ActivityType.cycling,
        weights: const {
          ScoreFactor.wind: 0.28,
          ScoreFactor.rain: 0.26,
          ScoreFactor.temperature: 0.22,
          ScoreFactor.airQuality: 0.13,
          ScoreFactor.uv: 0.11,
        },
        temperature: const RangeCurve(
          lowerLimit: 0,
          idealMin: 12,
          idealMax: 25,
          upperLimit: 36,
        ),
        rainProbability: const UpperLimitCurve(idealMax: 10, limit: 60),
        rainAmount: const UpperLimitCurve(idealMax: 0, limit: 2),
        wind: const UpperLimitCurve(idealMax: 10, limit: 40),
        uv: const UpperLimitCurve(idealMax: 3, limit: 11),
        airQuality: const UpperLimitCurve(idealMax: 50, limit: 180),
        hardLimits: [
          ..._commonLimits(),
          const HardLimit(
            metric: LimitMetric.windSpeed,
            threshold: 45,
            maxScore: 39,
            message: 'Viento muy fuerte para ir en bicicleta.',
          ),
          const HardLimit(
            metric: LimitMetric.windSpeed,
            threshold: 35,
            maxScore: 59,
            message: 'Viento fuerte para ir en bicicleta.',
          ),
        ],
      ),
    },
  );

  /// Límites duros comunes a todas las actividades.
  static List<HardLimit> _commonLimits() => const [
        HardLimit(
          metric: LimitMetric.precipitationProbability,
          threshold: 80,
          maxScore: 39,
          message: 'Probabilidad de lluvia muy alta.',
        ),
        HardLimit(
          metric: LimitMetric.precipitationAmount,
          threshold: 4,
          maxScore: 39,
          message: 'Se prevé lluvia intensa.',
        ),
        HardLimit(
          metric: LimitMetric.usAqi,
          threshold: 151,
          maxScore: 39,
          message: 'Calidad del aire dañina (US AQI 151 o más).',
        ),
        HardLimit(
          metric: LimitMetric.usAqi,
          threshold: 101,
          maxScore: 59,
          message: 'Calidad del aire dañina para grupos sensibles (US AQI 101 o más).',
        ),
        HardLimit(
          metric: LimitMetric.apparentTemperature,
          threshold: 36,
          maxScore: 39,
          message: 'Sensación térmica extrema por calor.',
        ),
        HardLimit(
          metric: LimitMetric.apparentTemperature,
          threshold: -5,
          maxScore: 39,
          whenAbove: false,
          message: 'Sensación térmica extrema por frío.',
        ),
        HardLimit(
          metric: LimitMetric.uvIndex,
          threshold: 11,
          maxScore: 59,
          message: 'Radiación UV extrema.',
        ),
      ];
}
