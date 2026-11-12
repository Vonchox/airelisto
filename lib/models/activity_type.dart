import 'package:material_ui/material_ui.dart';

import '../core/constants/app_assets.dart';

/// Actividades físicas al aire libre que soporta la aplicación.
enum ActivityType {
  walking('walking', 'Caminar', 'caminar', Icons.directions_walk_rounded,
      AppAssets.activityWalking),
  running('running', 'Correr', 'correr', Icons.directions_run_rounded,
      AppAssets.activityRunning),
  cycling('cycling', 'Bicicleta', 'montar bicicleta',
      Icons.directions_bike_rounded, AppAssets.activityCycling);

  const ActivityType(this.id, this.label, this.verb, this.icon, this.imageAsset);

  /// Identificador estable usado al guardar en almacenamiento local.
  final String id;

  /// Nombre corto para botones y chips.
  final String label;

  /// Verbo en infinitivo para frases ("buen momento para caminar").
  final String verb;

  final IconData icon;

  /// Ruta (opcional) de la imagen representativa de la actividad.
  final String imageAsset;

  static ActivityType fromId(String? id) => ActivityType.values.firstWhere(
        (activity) => activity.id == id,
        orElse: () => ActivityType.walking,
      );
}
