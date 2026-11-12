import 'package:material_ui/material_ui.dart';

/// Paleta de AireListo.
///
/// Los valores siguen la paleta sugerida. El texto secundario se oscureció un
/// poco (#5B6B63 en lugar de #718078) para alcanzar un contraste de 4.5:1 o
/// más sobre los fondos claros.
class AppColors {
  AppColors._();

  static const Color forest = Color(0xFF245C4F);
  static const Color forestSecondary = Color(0xFF4C987A);
  static const Color mint = Color(0xFFE6F2EC);
  static const Color sky = Color(0xFF69A9D0);
  static const Color background = Color(0xFFF6F8F7);
  static const Color white = Color(0xFFFFFFFF);
  static const Color caution = Color(0xFFF2C14E);
  static const Color warning = Color(0xFFD96B64);
  static const Color textPrimary = Color(0xFF24332E);
  static const Color textSecondary = Color(0xFF5B6B63);

  /// Borde sutil de tarjetas y separadores.
  static const Color outline = Color(0xFFDCE6E1);

  // Variantes suaves (fondos de insignias) y su texto oscuro asociado.
  static const Color cautionSoft = Color(0xFFFDF3D8);
  static const Color onCautionSoft = Color(0xFF6B4E00);
  static const Color warningSoft = Color(0xFFFBE6E4);
  static const Color onWarningSoft = Color(0xFF8E332D);
  static const Color goodSoft = Color(0xFFE3F2EA);
  static const Color onGoodSoft = Color(0xFF2B6650);

  // Colores adicionales para la escala del índice de calidad del aire.
  static const Color aqiOrange = Color(0xFFE8944A);
  static const Color aqiPurple = Color(0xFF8E5BA8);
  static const Color aqiMaroon = Color(0xFF7E2F3C);
}
