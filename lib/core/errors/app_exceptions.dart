/// Excepciones propias de la aplicación. Cada una lleva un mensaje en español
/// pensado para mostrarse directamente al usuario.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// No hay conexión a internet o no se pudo alcanzar el servidor.
class NoConnectionException extends AppException {
  const NoConnectionException([
    super.message =
        'Sin conexión a internet. Revisa tu red e inténtalo de nuevo.',
  ]);
}

/// El servidor respondió con un error (4xx/5xx).
class ServerException extends AppException {
  const ServerException(this.statusCode, [String? detail])
      : super(detail ?? 'El servidor respondió con un error ($statusCode).');

  final int statusCode;
}

/// Se superó el límite de solicitudes del servicio.
class RateLimitException extends AppException {
  const RateLimitException([
    super.message =
        'Se hicieron demasiadas solicitudes al servicio. Espera un momento e inténtalo de nuevo.',
  ]);
}

/// El servicio no está disponible temporalmente o tardó demasiado.
class ServiceUnavailableException extends AppException {
  const ServiceUnavailableException([
    super.message =
        'El servicio no está disponible por ahora o tardó demasiado en responder. Inténtalo de nuevo en unos minutos.',
  ]);
}

/// La respuesta del servidor no tiene el formato esperado.
class UnexpectedResponseException extends AppException {
  const UnexpectedResponseException([
    super.message = 'La respuesta del servicio tiene un formato inesperado.',
  ]);
}

/// El usuario no concedió el permiso de ubicación.
class LocationPermissionException extends AppException {
  const LocationPermissionException({this.permanentlyDenied = false})
      : super(
          permanentlyDenied
              ? 'El permiso de ubicación está bloqueado. Actívalo desde los ajustes del sistema o busca una ciudad manualmente.'
              : 'No se concedió el permiso de ubicación. Puedes buscar una ciudad manualmente.',
        );

  final bool permanentlyDenied;
}

/// El GPS o los servicios de ubicación del dispositivo están apagados.
class LocationDisabledException extends AppException {
  const LocationDisabledException()
      : super(
          'Los servicios de ubicación están desactivados. Actívalos o busca una ciudad manualmente.',
        );
}

/// No fue posible obtener la posición (por ejemplo, tiempo de espera agotado).
class LocationUnavailableException extends AppException {
  const LocationUnavailableException()
      : super(
          'No se pudo obtener tu posición en este momento. Inténtalo de nuevo o busca una ciudad.',
        );
}

/// Convierte cualquier error en un mensaje comprensible para el usuario.
String describeError(Object error) {
  if (error is AppException) return error.message;
  return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
}
