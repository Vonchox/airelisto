import 'package:flutter/foundation.dart';

/// Pestaña activa de la navegación inferior. Permite que cualquier pantalla
/// (por ejemplo, la tarjeta de recomendación de Inicio) cambie de pestaña.
class NavigationProvider extends ChangeNotifier {
  static const int home = 0;
  static const int recommendations = 1;
  static const int explore = 2;
  static const int plans = 3;
  static const int profile = 4;

  int _index = home;

  int get index => _index;

  void goTo(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}
