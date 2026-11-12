import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';

/// Cliente HTTP común a todos los servicios REST.
///
/// Conserva el enfoque del proyecto de clase (paquete `http`, `jsonDecode`,
/// comprobación del código de estado) y centraliza lo que antes se repetía en
/// cada método: tiempo de espera, cabeceras, decodificación UTF-8 y traducción
/// de errores a [AppException] con mensajes comprensibles.
class ApiClient {
  ApiClient({http.Client? client, Duration? timeout})
      : _client = client ?? http.Client(),
        _timeout = timeout ?? AppConstants.requestTimeout;

  final http.Client _client;
  final Duration _timeout;

  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'User-Agent': AppConstants.userAgent,
  };

  /// GET que devuelve un objeto JSON.
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    return _send(
      () => _client.get(uri, headers: {..._defaultHeaders, ...?headers}),
      timeout ?? _timeout,
    );
  }

  /// POST con cuerpo `application/x-www-form-urlencoded` (lo usa Overpass).
  Future<Map<String, dynamic>> postForm(
    Uri uri,
    Map<String, String> body, {
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    return _send(
      () => _client.post(
        uri,
        headers: {..._defaultHeaders, ...?headers},
        body: body,
      ),
      timeout ?? _timeout,
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
    Duration timeout,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const ServiceUnavailableException();
    } on http.ClientException {
      throw const NoConnectionException();
    }

    final status = response.statusCode;
    if (status == 429) throw const RateLimitException();
    if (status == 502 || status == 503 || status == 504) {
      throw const ServiceUnavailableException();
    }
    if (status < 200 || status >= 300) {
      throw ServerException(status, _errorDetail(response, status));
    }

    // El cuerpo se decodifica explícitamente como UTF-8: algunos servicios no
    // declaran el charset y `response.body` asumiría Latin-1.
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const UnexpectedResponseException(
        'La respuesta del servicio no es un JSON válido.',
      );
    }
    if (decoded is Map<String, dynamic>) return decoded;
    throw const UnexpectedResponseException();
  }

  /// Open-Meteo devuelve `{"error": true, "reason": "..."}` en los errores 4xx.
  String _errorDetail(http.Response response, int status) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic> && decoded['reason'] is String) {
        return 'El servicio rechazó la solicitud: ${decoded['reason']}';
      }
    } catch (_) {
      // El cuerpo no es JSON: se usa el mensaje genérico.
    }
    if (status >= 500) {
      return 'El servidor tuvo un problema ($status). Inténtalo de nuevo más tarde.';
    }
    return 'La solicitud no pudo completarse ($status).';
  }

  void close() => _client.close();
}
