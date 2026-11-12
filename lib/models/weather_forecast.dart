import '../core/errors/app_exceptions.dart';
import '../core/utils/date_text.dart';
import '../core/utils/json_reader.dart';

/// Condiciones actuales (`current` de Open-Meteo).
class CurrentWeather {
  const CurrentWeather({
    required this.time,
    this.temperature,
    this.apparentTemperature,
    this.relativeHumidity,
    this.precipitation,
    this.windSpeed,
    this.weatherCode,
    this.isDay = true,
  });

  final DateTime time;
  final double? temperature;
  final double? apparentTemperature;
  final double? relativeHumidity;
  final double? precipitation;
  final double? windSpeed;
  final int? weatherCode;
  final bool isDay;

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    final isDay = json['is_day'];
    return CurrentWeather(
      time: JsonReader.wallClock(json['time'], 'current.time'),
      temperature: JsonReader.doubleOrNull(json['temperature_2m']),
      apparentTemperature: JsonReader.doubleOrNull(json['apparent_temperature']),
      relativeHumidity: JsonReader.doubleOrNull(json['relative_humidity_2m']),
      precipitation: JsonReader.doubleOrNull(json['precipitation']),
      windSpeed: JsonReader.doubleOrNull(json['wind_speed_10m']),
      weatherCode: JsonReader.intOrNull(json['weather_code']),
      isDay: isDay is num ? isDay == 1 : true,
    );
  }
}

/// Condiciones previstas para una hora.
class HourlyWeather {
  const HourlyWeather({
    required this.time,
    this.temperature,
    this.apparentTemperature,
    this.precipitationProbability,
    this.precipitation,
    this.windSpeed,
    this.uvIndex,
    this.weatherCode,
  });

  /// Hora local de la ubicación (representada en UTC; ver [JsonReader]).
  final DateTime time;
  final double? temperature;
  final double? apparentTemperature;

  /// Probabilidad de precipitación en %.
  final double? precipitationProbability;

  /// Precipitación acumulada en la hora, en mm.
  final double? precipitation;

  /// Velocidad del viento a 10 m en km/h.
  final double? windSpeed;
  final double? uvIndex;
  final int? weatherCode;
}

/// Resumen previsto para un día.
class DailyWeather {
  const DailyWeather({
    required this.date,
    this.weatherCode,
    this.temperatureMax,
    this.temperatureMin,
    this.precipitationProbabilityMax,
    this.precipitationSum,
    this.uvIndexMax,
    this.windSpeedMax,
    this.sunrise,
    this.sunset,
  });

  final DateTime date;
  final int? weatherCode;
  final double? temperatureMax;
  final double? temperatureMin;
  final double? precipitationProbabilityMax;
  final double? precipitationSum;
  final double? uvIndexMax;
  final double? windSpeedMax;
  final DateTime? sunrise;
  final DateTime? sunset;
}

/// Respuesta completa de Open-Meteo Weather Forecast API ya validada.
class WeatherForecast {
  const WeatherForecast({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.utcOffsetSeconds,
    required this.hourly,
    required this.daily,
    this.current,
  });

  final double latitude;
  final double longitude;
  final String timezone;
  final int utcOffsetSeconds;
  final CurrentWeather? current;
  final List<HourlyWeather> hourly;
  final List<DailyWeather> daily;

  /// Convierte el JSON de `/v1/forecast`.
  ///
  /// Lanza [UnexpectedResponseException] si faltan las secciones
  /// imprescindibles (`hourly` y `daily` con sus fechas). Las variables
  /// individuales que falten quedan en `null` y se tratan como datos
  /// incompletos más adelante.
  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final hourlyJson = JsonReader.map(json['hourly'], 'hourly');
    final dailyJson = JsonReader.map(json['daily'], 'daily');

    final hourly = _parseHourly(hourlyJson);
    final daily = _parseDaily(dailyJson);
    if (hourly.isEmpty || daily.isEmpty) {
      throw const UnexpectedResponseException(
        'El servicio no devolvió datos de pronóstico para esta ubicación.',
      );
    }

    final currentJson = json['current'];
    return WeatherForecast(
      latitude: JsonReader.requiredDouble(json['latitude'], 'latitude'),
      longitude: JsonReader.requiredDouble(json['longitude'], 'longitude'),
      timezone: json['timezone'] is String ? json['timezone'] as String : 'UTC',
      utcOffsetSeconds: JsonReader.intOrNull(json['utc_offset_seconds']) ?? 0,
      current: currentJson is Map<String, dynamic>
          ? CurrentWeather.fromJson(currentJson)
          : null,
      hourly: hourly,
      daily: daily,
    );
  }

  static List<HourlyWeather> _parseHourly(Map<String, dynamic> json) {
    final times = JsonReader.list(json['time'], 'hourly.time');
    final count = times.length;
    final temperature = JsonReader.doubleSeries(json, 'temperature_2m', count);
    final apparent = JsonReader.doubleSeries(json, 'apparent_temperature', count);
    final probability =
        JsonReader.doubleSeries(json, 'precipitation_probability', count);
    final precipitation = JsonReader.doubleSeries(json, 'precipitation', count);
    final wind = JsonReader.doubleSeries(json, 'wind_speed_10m', count);
    final uv = JsonReader.doubleSeries(json, 'uv_index', count);
    final codes = JsonReader.intSeries(json, 'weather_code', count);

    return List<HourlyWeather>.generate(count, (i) {
      return HourlyWeather(
        time: JsonReader.wallClock(times[i], 'hourly.time'),
        temperature: temperature[i],
        apparentTemperature: apparent[i],
        precipitationProbability: probability[i],
        precipitation: precipitation[i],
        windSpeed: wind[i],
        uvIndex: uv[i],
        weatherCode: codes[i],
      );
    });
  }

  static List<DailyWeather> _parseDaily(Map<String, dynamic> json) {
    final times = JsonReader.list(json['time'], 'daily.time');
    final count = times.length;
    final codes = JsonReader.intSeries(json, 'weather_code', count);
    final max = JsonReader.doubleSeries(json, 'temperature_2m_max', count);
    final min = JsonReader.doubleSeries(json, 'temperature_2m_min', count);
    final probability =
        JsonReader.doubleSeries(json, 'precipitation_probability_max', count);
    final precipitation = JsonReader.doubleSeries(json, 'precipitation_sum', count);
    final uv = JsonReader.doubleSeries(json, 'uv_index_max', count);
    final wind = JsonReader.doubleSeries(json, 'wind_speed_10m_max', count);
    final sunrise = JsonReader.wallClockSeries(json, 'sunrise', count);
    final sunset = JsonReader.wallClockSeries(json, 'sunset', count);

    return List<DailyWeather>.generate(count, (i) {
      return DailyWeather(
        date: JsonReader.wallClock(times[i], 'daily.time'),
        weatherCode: codes[i],
        temperatureMax: max[i],
        temperatureMin: min[i],
        precipitationProbabilityMax: probability[i],
        precipitationSum: precipitation[i],
        uvIndexMax: uv[i],
        windSpeedMax: wind[i],
        sunrise: sunrise[i],
        sunset: sunset[i],
      );
    });
  }

  /// Fecha y hora actuales en la ubicación consultada (hora de pared en UTC).
  DateTime nowAtLocation({DateTime? now}) =>
      (now ?? DateTime.now()).toUtc().add(Duration(seconds: utcOffsetSeconds));

  /// Horas previstas para el día de [date].
  List<HourlyWeather> hoursOfDay(DateTime date) =>
      hourly.where((hour) => DateText.isSameDay(hour.time, date)).toList();

  /// Hora prevista que contiene a [wallClock], o `null` si no está en el rango.
  HourlyWeather? hourAt(DateTime wallClock) {
    for (final hour in hourly) {
      if (DateText.isSameDay(hour.time, wallClock) &&
          hour.time.hour == wallClock.hour) {
        return hour;
      }
    }
    return null;
  }

  /// Resumen diario correspondiente a [date], o `null` si no está en el rango.
  DailyWeather? dailyFor(DateTime date) {
    for (final day in daily) {
      if (DateText.isSameDay(day.date, date)) return day;
    }
    return null;
  }

  /// Variables por hora con al menos un valor ausente. Se usa para avisar al
  /// usuario de que la puntuación se calculó con datos incompletos.
  List<String> get incompleteVariables {
    final missing = <String>[];
    if (hourly.any((h) => h.temperature == null && h.apparentTemperature == null)) {
      missing.add('temperatura');
    }
    if (hourly.any((h) => h.precipitationProbability == null)) {
      missing.add('probabilidad de lluvia');
    }
    if (hourly.any((h) => h.windSpeed == null)) missing.add('viento');
    if (hourly.any((h) => h.uvIndex == null)) missing.add('índice UV');
    return missing;
  }
}
