import 'package:material_ui/material_ui.dart';

import '../core/constants/app_colors.dart';
import '../models/air_quality.dart';
import '../models/place.dart';
import '../models/recommendation.dart';

/// Colores e iconos asociados a los modelos. Mantienen la lógica de
/// presentación fuera de los modelos y de la lógica de recomendaciones.
extension ScoreCategoryUi on ScoreCategory {
  Color get color {
    switch (this) {
      case ScoreCategory.excellent:
        return AppColors.forest;
      case ScoreCategory.good:
        return AppColors.forestSecondary;
      case ScoreCategory.caution:
        return AppColors.caution;
      case ScoreCategory.poor:
        return AppColors.warning;
    }
  }

  Color get softColor {
    switch (this) {
      case ScoreCategory.excellent:
        return AppColors.mint;
      case ScoreCategory.good:
        return AppColors.goodSoft;
      case ScoreCategory.caution:
        return AppColors.cautionSoft;
      case ScoreCategory.poor:
        return AppColors.warningSoft;
    }
  }

  /// Color de texto con buen contraste sobre [softColor].
  Color get onSoftColor {
    switch (this) {
      case ScoreCategory.excellent:
        return AppColors.forest;
      case ScoreCategory.good:
        return AppColors.onGoodSoft;
      case ScoreCategory.caution:
        return AppColors.onCautionSoft;
      case ScoreCategory.poor:
        return AppColors.onWarningSoft;
    }
  }

  IconData get icon {
    switch (this) {
      case ScoreCategory.excellent:
        return Icons.check_circle_rounded;
      case ScoreCategory.good:
        return Icons.thumb_up_alt_rounded;
      case ScoreCategory.caution:
        return Icons.warning_amber_rounded;
      case ScoreCategory.poor:
        return Icons.cancel_rounded;
    }
  }
}

extension ScoreFactorUi on ScoreFactor {
  IconData get icon {
    switch (this) {
      case ScoreFactor.temperature:
        return Icons.thermostat_rounded;
      case ScoreFactor.rain:
        return Icons.water_drop_outlined;
      case ScoreFactor.wind:
        return Icons.air_rounded;
      case ScoreFactor.uv:
        return Icons.wb_sunny_outlined;
      case ScoreFactor.airQuality:
        return Icons.masks_rounded;
    }
  }
}

extension AqiCategoryUi on AqiCategory {
  Color get color {
    switch (this) {
      case AqiCategory.good:
        return AppColors.forestSecondary;
      case AqiCategory.moderate:
        return AppColors.caution;
      case AqiCategory.unhealthySensitive:
        return AppColors.aqiOrange;
      case AqiCategory.unhealthy:
        return AppColors.warning;
      case AqiCategory.veryUnhealthy:
        return AppColors.aqiPurple;
      case AqiCategory.hazardous:
        return AppColors.aqiMaroon;
    }
  }

  Color get softColor => color.withValues(alpha: 0.16);

  /// Texto oscuro legible sobre [softColor].
  Color get onSoftColor {
    switch (this) {
      case AqiCategory.good:
        return AppColors.onGoodSoft;
      case AqiCategory.moderate:
        return AppColors.onCautionSoft;
      case AqiCategory.unhealthySensitive:
        return const Color(0xFF7A3F0B);
      case AqiCategory.unhealthy:
        return AppColors.onWarningSoft;
      case AqiCategory.veryUnhealthy:
        return const Color(0xFF55307A);
      case AqiCategory.hazardous:
        return AppColors.aqiMaroon;
    }
  }
}

extension PlaceKindUi on PlaceKind {
  IconData get icon {
    switch (this) {
      case PlaceKind.park:
        return Icons.park_rounded;
      case PlaceKind.garden:
        return Icons.local_florist_rounded;
      case PlaceKind.natureReserve:
        return Icons.forest_rounded;
      case PlaceKind.recreationArea:
        return Icons.landscape_rounded;
      case PlaceKind.athleticsTrack:
        return Icons.stadium_rounded;
      case PlaceKind.sportsPitch:
        return Icons.sports_rounded;
      case PlaceKind.footpath:
        return Icons.directions_walk_rounded;
      case PlaceKind.hikingRoute:
        return Icons.hiking_rounded;
      case PlaceKind.cycleway:
        return Icons.pedal_bike_rounded;
      case PlaceKind.bicycleRoute:
        return Icons.route_rounded;
      case PlaceKind.cyclingTrack:
        return Icons.pedal_bike_rounded;
      case PlaceKind.sharedPath:
        return Icons.alt_route_rounded;
      case PlaceKind.other:
        return Icons.place_rounded;
    }
  }
}
