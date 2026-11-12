import 'package:material_ui/material_ui.dart';

import '../models/recommendation.dart';
import 'ui_extensions.dart';

/// Círculo con la puntuación (0 a 100) coloreado según su categoría.
class ScoreBadge extends StatelessWidget {
  const ScoreBadge({
    super.key,
    required this.score,
    required this.category,
    this.size = 56,
  });

  final int score;
  final ScoreCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Puntuación $score de 100, ${category.label}',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: category.softColor,
          shape: BoxShape.circle,
          border: Border.all(color: category.color, width: 2.5),
        ),
        child: Text(
          '$score',
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            color: category.onSoftColor,
          ),
        ),
      ),
    );
  }
}

/// Etiqueta con el nombre de la categoría ("Excelente", "Bueno"...).
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.category, this.dense = false});

  final ScoreCategory category;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: category.softColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: dense ? 13 : 16, color: category.onSoftColor),
          const SizedBox(width: 5),
          Text(
            category.label,
            style: TextStyle(
              fontSize: dense ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: category.onSoftColor,
            ),
          ),
        ],
      ),
    );
  }
}
