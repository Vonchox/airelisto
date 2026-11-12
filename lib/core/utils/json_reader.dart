import '../errors/app_exceptions.dart';

/// Utilidades para leer JSON de forma defensiva.
///
/// Open-Meteo devuelve las horas en la zona horaria de la ubicación consultada
/// (`timezone=auto`) y sin desplazamiento, por ejemplo `2026-11-10T14:00`.
/// Esas fechas se interpretan como "hora de pared" de la ubicación y se
/// representan con un [DateTime] en UTC con los mismos componentes. Así todas
/// las comparaciones son coherentes sin importar la zona horaria del teléfono.
class JsonReader {
  JsonReader._();

  static Map<String, dynamic> map(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    throw UnexpectedResponseException(
      'La respuesta del servicio no incluye "$what" con el formato esperado.',
    );
  }

  static List<dynamic> list(Object? value, String what) {
    if (value is List<dynamic>) return value;
    throw UnexpectedResponseException(
      'La respuesta del servicio no incluye la lista "$what".',
    );
  }

  static double? doubleOrNull(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    return null;
  }

  static int? intOrNull(Object? value) {
    if (value is num && value.isFinite) return value.toInt();
    return null;
  }

  static double requiredDouble(Object? value, String what) {
    final result = doubleOrNull(value);
    if (result == null) {
      throw UnexpectedResponseException(
        'Falta el dato numérico "$what" en la respuesta del servicio.',
      );
    }
    return result;
  }

  /// Serie numérica opcional. Si la clave no existe, o tiene menos elementos
  /// que [length], las posiciones sin dato quedan en `null`.
  static List<double?> doubleSeries(
    Map<String, dynamic> json,
    String key,
    int length,
  ) {
    final raw = json[key];
    if (raw is! List<dynamic>) {
      return List<double?>.filled(length, null);
    }
    return List<double?>.generate(
      length,
      (index) => index < raw.length ? doubleOrNull(raw[index]) : null,
    );
  }

  static List<int?> intSeries(
    Map<String, dynamic> json,
    String key,
    int length,
  ) {
    final raw = json[key];
    if (raw is! List<dynamic>) {
      return List<int?>.filled(length, null);
    }
    return List<int?>.generate(
      length,
      (index) => index < raw.length ? intOrNull(raw[index]) : null,
    );
  }

  /// Serie de fechas opcionales (por ejemplo amanecer y atardecer).
  static List<DateTime?> wallClockSeries(
    Map<String, dynamic> json,
    String key,
    int length,
  ) {
    final raw = json[key];
    if (raw is! List<dynamic>) {
      return List<DateTime?>.filled(length, null);
    }
    return List<DateTime?>.generate(length, (index) {
      if (index >= raw.length) return null;
      return wallClockOrNull(raw[index]);
    });
  }

  /// Convierte `2026-11-10T14:00` o `2026-11-10` en un [DateTime] UTC con los
  /// mismos componentes (hora local de la ubicación).
  static DateTime? wallClockOrNull(Object? value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
    );
  }

  static DateTime wallClock(Object? value, String what) {
    final result = wallClockOrNull(value);
    if (result == null) {
      throw UnexpectedResponseException(
        'La fecha "$what" de la respuesta tiene un formato inesperado.',
      );
    }
    return result;
  }
}
