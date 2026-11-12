/// Formato de fechas y horas en español sin depender de paquetes externos.
class DateText {
  DateText._();

  static const List<String> _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const List<String> _weekdaysShort = [
    'lun',
    'mar',
    'mié',
    'jue',
    'vie',
    'sáb',
    'dom',
  ];

  static const List<String> _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static String two(int value) => value.toString().padLeft(2, '0');

  /// `07:30`
  static String hour(DateTime date) => '${two(date.hour)}:${two(date.minute)}';

  /// `07:00 – 09:00`
  static String hourRange(DateTime start, DateTime end) =>
      '${hour(start)} – ${hour(end)}';

  static String weekday(DateTime date) => _weekdays[date.weekday - 1];

  static String weekdayShort(DateTime date) => _weekdaysShort[date.weekday - 1];

  static String month(DateTime date) => _months[date.month - 1];

  /// `10 de noviembre`
  static String dayMonth(DateTime date) => '${date.day} de ${month(date)}';

  /// `Martes 10 de noviembre`
  static String fullDate(DateTime date) =>
      capitalize('${weekday(date)} ${dayMonth(date)}');

  /// `10/11/2026`
  static String numeric(DateTime date) =>
      '${two(date.day)}/${two(date.month)}/${date.year}';

  /// `2026-11-10`
  static String isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// `Hoy`, `Mañana` o el nombre del día, según la distancia a [today].
  static String relativeDay(DateTime date, DateTime today) {
    final a = DateTime.utc(date.year, date.month, date.day);
    final b = DateTime.utc(today.year, today.month, today.day);
    final difference = a.difference(b).inDays;
    if (difference == 0) return 'Hoy';
    if (difference == 1) return 'Mañana';
    return capitalize(weekday(date));
  }

  /// `hoy a las 14:32`, `ayer a las 09:10` o `10/11 a las 09:10`.
  static String lastUpdated(DateTime time, DateTime now) {
    final timeText = hour(time);
    if (isSameDay(time, now)) return 'hoy a las $timeText';
    final yesterday = now.subtract(const Duration(days: 1));
    if (isSameDay(time, yesterday)) return 'ayer a las $timeText';
    return '${two(time.day)}/${two(time.month)} a las $timeText';
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
