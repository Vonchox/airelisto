import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/unit_formatter.dart';
import '../models/activity_type.dart';
import '../services/storage_service.dart';

/// Preferencias del usuario: actividad seleccionada, unidades y radio de
/// búsqueda de lugares. Se guardan localmente.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage) {
    final json = _storage.readJsonMap(StorageService.settingsKey);
    if (json != null) {
      _activity = ActivityType.fromId(json['activity'] as String?);
      _units = UnitSystem.fromName(json['units'] as String?);
      final radius = json['radius'];
      if (radius is int && AppConstants.searchRadiusOptionsMeters.contains(radius)) {
        _searchRadiusMeters = radius;
      }
    }
  }

  final StorageService _storage;

  ActivityType _activity = ActivityType.walking;
  UnitSystem _units = UnitSystem.metric;
  int _searchRadiusMeters = AppConstants.defaultSearchRadiusMeters;

  ActivityType get activity => _activity;
  UnitSystem get units => _units;
  int get searchRadiusMeters => _searchRadiusMeters;
  UnitFormatter get formatter => UnitFormatter(_units);

  void setActivity(ActivityType value) {
    if (value == _activity) return;
    _activity = value;
    _persistAndNotify();
  }

  void setUnits(UnitSystem value) {
    if (value == _units) return;
    _units = value;
    _persistAndNotify();
  }

  void setSearchRadius(int meters) {
    if (meters == _searchRadiusMeters) return;
    _searchRadiusMeters = meters;
    _persistAndNotify();
  }

  void _persistAndNotify() {
    notifyListeners();
    _storage.writeJson(StorageService.settingsKey, {
      'activity': _activity.id,
      'units': _units.name,
      'radius': _searchRadiusMeters,
    });
  }
}
