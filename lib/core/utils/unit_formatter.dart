/// Sistema de unidades que el usuario puede elegir en Configuración.
///
/// Los cálculos internos (puntuaciones, umbrales) siempre usan unidades
/// métricas; este formateador solo convierte lo que se muestra en pantalla.
enum UnitSystem {
  metric('Métrico (°C, km/h)'),
  imperial('Imperial (°F, mph)');

  const UnitSystem(this.label);

  final String label;

  static UnitSystem fromName(String? name) => UnitSystem.values.firstWhere(
        (unit) => unit.name == name,
        orElse: () => UnitSystem.metric,
      );
}

class UnitFormatter {
  const UnitFormatter(this.system);

  final UnitSystem system;

  bool get isMetric => system == UnitSystem.metric;

  /// Temperatura recibida en °C. Ejemplo: `23°` / `73°`.
  String temperature(double? celsius, {bool withUnit = false}) {
    if (celsius == null) return '–';
    final value = isMetric ? celsius : celsius * 9 / 5 + 32;
    final unit = withUnit ? (isMetric ? ' °C' : ' °F') : '°';
    return '${value.round()}$unit';
  }

  /// Velocidad del viento recibida en km/h.
  String wind(double? kmh) {
    if (kmh == null) return '–';
    if (isMetric) return '${kmh.round()} km/h';
    return '${(kmh * 0.621371).round()} mph';
  }

  /// Precipitación recibida en mm.
  String precipitation(double? mm) {
    if (mm == null) return '–';
    if (isMetric) return '${mm.toStringAsFixed(1)} mm';
    return '${(mm / 25.4).toStringAsFixed(2)} in';
  }

  /// Distancia recibida en metros.
  String distance(double? meters) {
    if (meters == null) return '–';
    if (isMetric) {
      if (meters < 1000) return '${(meters / 10).round() * 10} m';
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    final feet = meters * 3.28084;
    if (feet < 1000) return '${(feet / 10).round() * 10} ft';
    return '${(meters / 1609.344).toStringAsFixed(1)} mi';
  }

  String percent(double? value) {
    if (value == null) return '–';
    return '${value.round()} %';
  }

  String uv(double? value) {
    if (value == null) return '–';
    return value.toStringAsFixed(1);
  }
}
