import 'dart:convert';

import 'package:http/http.dart' as http;

/// Datos de prueba compartidos. Reproducen la estructura documentada de las
/// respuestas de Open-Meteo y Overpass.

String _two(int value) => value.toString().padLeft(2, '0');

/// `2026-11-10T14:00` para el día [dayOffset] (0 = 10 de noviembre de 2026).
String hourText(int dayOffset, int hour) =>
    '2026-11-${_two(10 + dayOffset)}T${_two(hour)}:00';

List<String> hourlyTimes(int days) => [
      for (var d = 0; d < days; d++)
        for (var h = 0; h < 24; h++) hourText(d, h),
    ];

/// Respuesta de `/v1/forecast` con valores constantes en todas las horas.
Map<String, dynamic> sampleWeatherJson({
  int days = 2,
  double apparent = 20,
  double rainProbability = 5,
  double rain = 0,
  double wind = 8,
  double uv = 2,
  bool includeUv = true,
}) {
  final times = hourlyTimes(days);
  List<num> fill(num value) => List<num>.filled(times.length, value);

  return {
    'latitude': -0.25,
    'longitude': -78.5,
    'utc_offset_seconds': -18000,
    'timezone': 'America/Guayaquil',
    'current': {
      'time': '2026-11-10T09:00',
      'interval': 900,
      'temperature_2m': 19.5,
      'relative_humidity_2m': 70,
      'apparent_temperature': 19.0,
      'is_day': 1,
      'precipitation': 0.0,
      'weather_code': 2,
      'wind_speed_10m': 7.2,
    },
    'hourly': <String, dynamic>{
      'time': times,
      'temperature_2m': fill(apparent + 1),
      'apparent_temperature': fill(apparent),
      'precipitation_probability': fill(rainProbability),
      'precipitation': fill(rain),
      'weather_code': fill(1),
      'wind_speed_10m': fill(wind),
      if (includeUv) 'uv_index': fill(uv),
    },
    'daily': {
      'time': [for (var d = 0; d < days; d++) '2026-11-${_two(10 + d)}'],
      'weather_code': List<num>.filled(days, 3),
      'temperature_2m_max': List<num>.filled(days, 22.4),
      'temperature_2m_min': List<num>.filled(days, 10.1),
      'precipitation_sum': List<num>.filled(days, 1.2),
      'precipitation_probability_max': List<num>.filled(days, 40),
      'uv_index_max': List<num>.filled(days, 9.5),
      'wind_speed_10m_max': List<num>.filled(days, 18.3),
      'sunrise': [for (var d = 0; d < days; d++) '2026-11-${_two(10 + d)}T06:08'],
      'sunset': [for (var d = 0; d < days; d++) '2026-11-${_two(10 + d)}T18:10'],
    },
  };
}

/// Respuesta de `/v1/air-quality`.
Map<String, dynamic> sampleAirQualityJson({int days = 2, double aqi = 42}) {
  final times = hourlyTimes(days);
  return {
    'latitude': -0.25,
    'longitude': -78.5,
    'current': {
      'time': '2026-11-10T09:00',
      'interval': 3600,
      'us_aqi': aqi,
      'pm10': 18.5,
      'pm2_5': 9.1,
    },
    'hourly': <String, dynamic>{
      'time': times,
      'us_aqi': List<num>.filled(times.length, aqi),
      'pm10': List<num>.filled(times.length, 18.5),
      'pm2_5': List<num>.filled(times.length, 9.1),
    },
  };
}

/// Respuesta de `/v1/search` del geocodificador.
Map<String, dynamic> sampleGeocodingJson() => {
      'results': [
        {
          'id': 3688689,
          'name': 'Bogotá',
          'latitude': 4.60971,
          'longitude': -74.08175,
          'country_code': 'CO',
          'admin1': 'Bogotá D.C.',
          'country': 'Colombia',
        },
        {
          'id': 1,
          'name': 'Sin coordenadas',
        },
      ],
      'generationtime_ms': 0.8,
    };

/// Respuesta de Overpass con `out center tags`.
Map<String, dynamic> sampleOverpassJson() => {
      'version': 0.6,
      'generator': 'Overpass API',
      'elements': [
        {
          'type': 'way',
          'id': 101,
          'center': {'lat': -0.2250, 'lon': -78.5250},
          'tags': {'highway': 'cycleway', 'name': 'Ciclovía Norte', 'lit': 'yes'},
        },
        {
          'type': 'node',
          'id': 102,
          'lat': -0.2200,
          'lon': -78.5000,
          'tags': {'leisure': 'park', 'name': 'Parque La Carolina'},
        },
        {
          'type': 'relation',
          'id': 103,
          'center': {'lat': -0.2400, 'lon': -78.5100},
          'tags': {'route': 'bicycle', 'name': 'Ruta Verde'},
        },
        // Sin coordenadas: debe omitirse.
        {
          'type': 'way',
          'id': 104,
          'tags': {'leisure': 'park', 'name': 'Sin coordenadas'},
        },
        // Sin etiquetas útiles: se clasifica como "otro".
        {
          'type': 'node',
          'id': 105,
          'lat': -0.2300,
          'lon': -78.5200,
        },
        {
          'type': 'way',
          'id': 106,
          'center': {'lat': -0.2310, 'lon': -78.5210},
          'tags': {
            'leisure': 'track',
            'sport': 'athletics',
            'name': 'Pista Atlética',
          },
        },
      ],
    };

/// Respuesta HTTP UTF-8 con un cuerpo JSON.
http.Response jsonResponse(Object body, {int status = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );
}
