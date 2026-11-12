import 'package:material_ui/material_ui.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/unit_formatter.dart';
import '../models/recommendation.dart';
import 'ui_extensions.dart';

/// Texto del valor medido de un factor, con las unidades elegidas.
String factorValueText(FactorResult factor, UnitFormatter formatter) {
  final value = factor.value;
  switch (factor.factor) {
    case ScoreFactor.temperature:
      return formatter.temperature(value, withUnit: true);
    case ScoreFactor.rain:
      final amount = factor.secondaryValue;
      final probability = value == null ? null : formatter.percent(value);
      final amountText =
          amount != null && amount > 0 ? formatter.precipitation(amount) : null;
      if (probability != null && amountText != null) {
        return '$probability · $amountText';
      }
      return probability ?? amountText ?? '–';
    case ScoreFactor.wind:
      return formatter.wind(value);
    case ScoreFactor.uv:
      return 'UV ${formatter.uv(value)}';
    case ScoreFactor.airQuality:
      return value == null ? '–' : 'AQI ${value.round()}';
  }
}

/// Fila que muestra un factor: icono, descripción, valor y barra de puntuación.
class FactorRow extends StatelessWidget {
  const FactorRow({super.key, required this.factor, required this.formatter});

  final FactorResult factor;
  final UnitFormatter formatter;

  Color get _barColor {
    switch (factor.verdict) {
      case FactorVerdict.good:
        return AppColors.forestSecondary;
      case FactorVerdict.fair:
        return AppColors.caution;
      case FactorVerdict.poor:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final phrase = factor.phrase.isEmpty
        ? factor.phrase
        : factor.phrase[0].toUpperCase() + factor.phrase.substring(1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(factor.factor.icon, size: 20, color: AppColors.forest),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        factor.factor.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      factorValueText(factor, formatter),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$phrase · ${(factor.weight * 100).round()} % del peso',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (factor.score / 100).clamp(0.0, 1.0).toDouble(),
                    minHeight: 6,
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(_barColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
