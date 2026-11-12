import 'package:flutter/foundation.dart';

import '../models/planned_activity.dart';
import '../services/storage_service.dart';

/// Actividades planificadas por el usuario (se guardan localmente).
class PlannerProvider extends ChangeNotifier {
  PlannerProvider(this._storage) {
    for (final json in _storage.readJsonList(StorageService.plansKey)) {
      try {
        _plans.add(PlannedActivity.fromJson(json));
      } catch (_) {
        // Se ignoran los planes con formato inválido.
      }
    }
    _sort();
  }

  final StorageService _storage;
  final List<PlannedActivity> _plans = [];

  /// Todos los planes, ordenados por fecha y hora.
  List<PlannedActivity> get plans => List.unmodifiable(_plans);

  /// Planes cuya fecha y hora aún no pasaron (según el reloj del teléfono).
  List<PlannedActivity> upcoming({DateTime? now}) {
    final reference = now ?? DateTime.now();
    return _plans.where((p) => !p.dateTime.isBefore(reference)).toList();
  }

  /// Planes ya pasados, del más reciente al más antiguo.
  List<PlannedActivity> past({DateTime? now}) {
    final reference = now ?? DateTime.now();
    return _plans.where((p) => p.dateTime.isBefore(reference)).toList().reversed.toList();
  }

  /// Genera un identificador único para un plan nuevo.
  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> save(PlannedActivity plan) async {
    final index = _plans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      _plans[index] = plan;
    } else {
      _plans.add(plan);
    }
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    _plans.removeWhere((p) => p.id == id);
    notifyListeners();
    await _persist();
  }

  void _sort() => _plans.sort((a, b) => a.dateTime.compareTo(b.dateTime));

  Future<void> _persist() => _storage.writeJson(
        StorageService.plansKey,
        _plans.map((p) => p.toJson()).toList(),
      );
}
