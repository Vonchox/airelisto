import 'package:material_ui/material_ui.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/date_text.dart';
import '../core/utils/unit_formatter.dart';
import '../core/utils/weather_codes.dart';
import '../models/recommendation.dart';
import 'app_card.dart';
import 'factor_row.dart';
import 'score_badge.dart';

/// Tarjeta expandible con la puntuación de una hora y su explicación.
class HourRecommendationTile extends StatefulWidget {
  const HourRecommendationTile({
    super.key,
    required this.recommendation,
    required this.formatter,
    this.highlight = false,
    this.initiallyExpanded = false,
  });

  final HourRecommendation recommendation;
  final UnitFormatter formatter;

  /// Resalta la tarjeta (por ejemplo, la mejor hora del día).
  final bool highlight;
  final bool initiallyExpanded;

  @override
  State<HourRecommendationTile> createState() => _HourRecommendationTileState();
}

class _HourRecommendationTileState extends State<HourRecommendationTile> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final rec = widget.recommendation;
    final condition = WeatherCondition.fromCode(rec.weather.weatherCode);
    final end = rec.time.add(const Duration(hours: 1));

    return AppCard(
      color: widget.highlight ? AppColors.mint : null,
      padding: EdgeInsets.zero,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ScoreBadge(score: rec.score, category: rec.category, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateText.hourRange(rec.time, end),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          CategoryChip(category: rec.category, dense: true),
                          const SizedBox(width: 8),
                          Icon(condition.icon, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            widget.formatter.temperature(
                              rec.weather.temperature ?? rec.weather.apparentTemperature,
                            ),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              rec.summary,
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(height: 1.35),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _expanded ? _details(rec) : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(HourRecommendation rec) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 6),
        for (final factor in rec.factors)
          FactorRow(factor: factor, formatter: widget.formatter),
        if (rec.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final note in rec.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
