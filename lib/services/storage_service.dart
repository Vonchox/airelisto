import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Acceso sencillo a `shared_preferences` con lectura/escritura de JSON.
///
/// Los datos guardados pueden estar corruptos (por ejemplo, tras una
/// actualización de la app); todas las lecturas son tolerantes y devuelven
/// valores vacíos en lugar de lanzar excepciones.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static const String settingsKey = 'settings';
  static const String selectedLocationKey = 'selected_location';
  static const String favoriteLocationsKey = 'favorite_locations';
  static const String favoritePlacesKey = 'favorite_places';
  static const String plansKey = 'planned_activities';

  Map<String, dynamic>? readJsonMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  List<Map<String, dynamic>> readJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return const [];
      return decoded.whereType<Map<String, dynamic>>().toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> writeJson(String key, Object value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
