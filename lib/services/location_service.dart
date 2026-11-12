import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/errors/app_exceptions.dart';

/// Coordenadas obtenidas del GPS.
typedef Coordinates = ({double latitude, double longitude});

/// Obtiene la ubicación del dispositivo con `geolocator`, gestionando los
/// permisos de forma explícita.
///
/// Es una clase simple (no final) para poder sustituirla por un doble en
/// pruebas.
class LocationService {
  const LocationService();

  /// Solicita el permiso si hace falta y devuelve la posición actual.
  ///
  /// Lanza [LocationDisabledException], [LocationPermissionException] o
  /// [LocationUnavailableException].
  Future<Coordinates> getCurrentCoordinates() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw const LocationDisabledException();

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationPermissionException();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionException(permanentlyDenied: true);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } on TimeoutException {
      throw const LocationUnavailableException();
    }
  }

  /// `true` si ya hay permiso y el GPS está activo (no muestra diálogos).
  Future<bool> canReadSilently() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Abre los ajustes de la aplicación (cuando el permiso está bloqueado).
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Abre los ajustes de ubicación del sistema.
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
