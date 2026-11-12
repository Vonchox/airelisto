import 'package:material_ui/material_ui.dart';

/// Descripción e icono de un código meteorológico WMO (`weather_code` de
/// Open-Meteo). Referencia: https://open-meteo.com/en/docs (sección
/// "WMO Weather interpretation codes").
class WeatherCondition {
  const WeatherCondition(this.description, this.icon);

  final String description;
  final IconData icon;

  static WeatherCondition fromCode(int? code, {bool isDay = true}) {
    switch (code) {
      case 0:
        return WeatherCondition(
          'Despejado',
          isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
        );
      case 1:
        return WeatherCondition(
          'Mayormente despejado',
          isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
        );
      case 2:
        return const WeatherCondition('Parcialmente nublado', Icons.wb_cloudy_rounded);
      case 3:
        return const WeatherCondition('Nublado', Icons.cloud_rounded);
      case 45:
      case 48:
        return const WeatherCondition('Niebla', Icons.blur_on_rounded);
      case 51:
      case 53:
      case 55:
        return const WeatherCondition('Llovizna', Icons.grain_rounded);
      case 56:
      case 57:
        return const WeatherCondition('Llovizna helada', Icons.grain_rounded);
      case 61:
        return const WeatherCondition('Lluvia ligera', Icons.water_drop_rounded);
      case 63:
        return const WeatherCondition('Lluvia moderada', Icons.water_drop_rounded);
      case 65:
        return const WeatherCondition('Lluvia fuerte', Icons.umbrella_rounded);
      case 66:
      case 67:
        return const WeatherCondition('Lluvia helada', Icons.umbrella_rounded);
      case 71:
      case 73:
      case 75:
      case 77:
        return const WeatherCondition('Nieve', Icons.ac_unit_rounded);
      case 80:
        return const WeatherCondition('Chubascos ligeros', Icons.water_drop_rounded);
      case 81:
        return const WeatherCondition('Chubascos', Icons.umbrella_rounded);
      case 82:
        return const WeatherCondition('Chubascos violentos', Icons.umbrella_rounded);
      case 85:
      case 86:
        return const WeatherCondition('Chubascos de nieve', Icons.ac_unit_rounded);
      case 95:
        return const WeatherCondition('Tormenta', Icons.thunderstorm_rounded);
      case 96:
      case 99:
        return const WeatherCondition('Tormenta con granizo', Icons.thunderstorm_rounded);
      default:
        return const WeatherCondition('Sin datos', Icons.help_outline_rounded);
    }
  }
}
