import '../core/utils/json_reader.dart';

/// Categorías del índice **US AQI** (EPA). La aplicación usa únicamente esta
/// escala; no se mezcla con el índice europeo.
enum AqiCategory {
  good(
    'Buena',
    'Calidad del aire satisfactoria. Condiciones habituales para hacer actividad al aire libre.',
  ),
  moderate(
    'Moderada',
    'Aceptable para la mayoría de las personas. Quienes son muy sensibles a la contaminación podrían notar molestias en esfuerzos prolongados.',
  ),
  unhealthySensitive(
    'Dañina para grupos sensibles',
    'Precaución: las personas con asma o enfermedades respiratorias o cardíacas, los niños y los adultos mayores deberían reducir el esfuerzo intenso al aire libre.',
  ),
  unhealthy(
    'Dañina',
    'Conviene reducir el ejercicio intenso al aire libre; los grupos sensibles deberían evitarlo.',
  ),
  veryUnhealthy(
    'Muy dañina',
    'Se recomienda evitar el ejercicio al aire libre y considerar alternativas bajo techo.',
  ),
  hazardous(
    'Peligrosa',
    'Condiciones de emergencia por contaminación: evita las actividades al aire libre.',
  );

  const AqiCategory(this.label, this.advice);

  final String label;

  /// Texto orientativo general; no sustituye el consejo médico.
  final String advice;

  /// Clasifica un valor de US AQI. Devuelve `null` si no hay dato.
  static AqiCategory? fromUsAqi(double? aqi) {
    if (aqi == null) return null;
    final value = aqi.round();
    if (value <= 50) return AqiCategory.good;
    if (value <= 100) return AqiCategory.moderate;
    if (value <= 150) return AqiCategory.unhealthySensitive;
    if (value <= 200) return AqiCategory.unhealthy;
    if (value <= 300) return AqiCategory.veryUnhealthy;
    return AqiCategory.hazardous;
  }

  /// `true` cuando conviene mostrar una advertencia de precaución.
  bool get needsCaution => index >= AqiCategory.unhealthySensitive.index;
}

/// Medición o pronóstico de calidad del aire para una hora.
class AirQualityHour {
  const AirQualityHour({
    required this.time,
    this.usAqi,
    this.pm25,
    this.pm10,
  });

  final DateTime time;

  /// Índice US AQI (`us_aqi`).
  final double? usAqi;

  /// Partículas finas PM2.5 en µg/m³ (`pm2_5`).
  final double? pm25;

  /// Partículas PM10 en µg/m³ (`pm10`).
  final double? pm10;

  AqiCategory? get category => AqiCategory.fromUsAqi(usAqi);

  factory AirQualityHour.fromCurrentJson(Map<String, dynamic> json) {
    return AirQualityHour(
      time: JsonReader.wallClock(json['time'], 'current.time'),
      usAqi: JsonReader.doubleOrNull(json['us_aqi']),
      pm25: JsonReader.doubleOrNull(json['pm2_5']),
      pm10: JsonReader.doubleOrNull(json['pm10']),
    );
  }
}

/// Respuesta de Open-Meteo Air Quality API ya validada.
class AirQualityData {
  AirQualityData({
    required this.latitude,
    required this.longitude,
    required this.hourly,
    this.current,
  }) : _byTime = {for (final hour in hourly) hour.time: hour};

  final double latitude;
  final double longitude;
  final AirQualityHour? current;
  final List<AirQualityHour> hourly;
  final Map<DateTime, AirQualityHour> _byTime;

  factory AirQualityData.fromJson(Map<String, dynamic> json) {
    final hourlyJson = JsonReader.map(json['hourly'], 'hourly');
    final times = JsonReader.list(hourlyJson['time'], 'hourly.time');
    final count = times.length;
    final aqi = JsonReader.doubleSeries(hourlyJson, 'us_aqi', count);
    final pm25 = JsonReader.doubleSeries(hourlyJson, 'pm2_5', count);
    final pm10 = JsonReader.doubleSeries(hourlyJson, 'pm10', count);

    final hourly = List<AirQualityHour>.generate(count, (i) {
      return AirQualityHour(
        time: JsonReader.wallClock(times[i], 'hourly.time'),
        usAqi: aqi[i],
        pm25: pm25[i],
        pm10: pm10[i],
      );
    });

    final currentJson = json['current'];
    return AirQualityData(
      latitude: JsonReader.requiredDouble(json['latitude'], 'latitude'),
      longitude: JsonReader.requiredDouble(json['longitude'], 'longitude'),
      current: currentJson is Map<String, dynamic>
          ? AirQualityHour.fromCurrentJson(currentJson)
          : null,
      hourly: hourly,
    );
  }

  /// Dato de la hora que contiene a [wallClock] (hora local de la ubicación).
  AirQualityHour? hourAt(DateTime wallClock) {
    return _byTime[DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
    )];
  }

  /// Indica si hay al menos un valor de US AQI utilizable.
  bool get hasAqi => hourly.any((hour) => hour.usAqi != null) ||
      current?.usAqi != null;
}
