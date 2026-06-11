import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'models.dart';

/// Error de API con el mensaje legible del backend (ApiError.message /
/// FastAPI detail) para mostrarlo directo en la UI.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Cliente HTTP del portal móvil.
///
/// Hosts:
///   - Emulador Android → 10.0.2.2 (alias del localhost de tu PC).
///   - Web / desktop / iOS simulator → localhost.
///   - Teléfono físico → cambia [overrideHost] por la IP de tu PC en la
///     red local (ej. '192.168.0.10').
class PortalService {
  /// Host configurable en runtime desde la pantalla de login (sección
  /// "Ajustes de conexión"). Null → autodetección por plataforma
  /// (emulador Android 10.0.2.2, resto localhost).
  ///
  /// Para teléfono FÍSICO: la IP de tu laptop en la red Wi-Fi.
  /// Vuelve a ponerlo en `null` si usas emulador o cambia de red
  /// (verifica tu IP con `ipconfig` → "Dirección IPv4").
  static String? hostOverride = '192.168.0.8';

  static String get host {
    final manual = hostOverride?.trim();
    if (manual != null && manual.isNotEmpty) return manual;
    if (kIsWeb) return 'localhost';
    try {
      return Platform.isAndroid ? '10.0.2.2' : 'localhost';
    } catch (_) {
      return 'localhost';
    }
  }

  static String get _host => host;

  static String get apiBase => 'http://$_host:8080/api/mobile';
  static String get aiBase => 'http://$_host:8001';

  /// Sesión en memoria (credenciales que viajan en cada request).
  MobileSession? session;
  String? _ci;

  bool get isLoggedIn => session != null;

  // ── Auth + mis trámites ───────────────────────────────────────────────

  Future<List<CaseSummary>> login(String email, String ci) async {
    final body = await _postJson('$apiBase/login', {'email': email, 'ci': ci});
    session = MobileSession.fromJson(body);
    _ci = ci.trim();
    return ((body['cases'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CaseSummary.fromJson)
        .toList();
  }

  void logout() {
    session = null;
    _ci = null;
  }

  Future<List<CaseSummary>> getCases() async {
    final s = _requireSession();
    final uri = Uri.parse('$apiBase/cases').replace(
      queryParameters: {'email': s.email, 'ci': _ci ?? s.ci},
    );
    final body = await _getJson(uri.toString());
    return (body as List)
        .whereType<Map<String, dynamic>>()
        .map(CaseSummary.fromJson)
        .toList();
  }

  // ── Módulo 3: clasificación + inicio de trámite ───────────────────────

  /// Clasifica la necesidad. Con sesión envía las credenciales del
  /// cliente; sin sesión (cliente NUEVO desde "Iniciar un nuevo trámite")
  /// va en modo invitado — su identidad se crea recién con el formulario.
  Future<IntakeClassification> classifyIntake(String description) async {
    final s = session;
    final body = await _postJson('$aiBase/ai/classify-intake', {
      'email': s?.email ?? '',
      'ci': _ci ?? s?.ci ?? '',
      'description': description,
    });
    return IntakeClassification.fromJson(body);
  }

  Future<List<MobilePolicy>> listPolicies() async {
    final body = await _getJson('$apiBase/policies');
    return (body as List)
        .whereType<Map<String, dynamic>>()
        .map(MobilePolicy.fromJson)
        .toList();
  }

  Future<MobilePolicy> getPolicy(String policyId) async {
    final body = await _getJson('$apiBase/policies/$policyId');
    return MobilePolicy.fromJson(body);
  }

  /// Inicia el trámite; devuelve el código generado (ej. "CASE-AB12CD34").
  Future<String> startCase(
      String policyId, Map<String, dynamic> startFormData) async {
    final s = _requireSession();
    final body = await _postJson('$apiBase/start-case', {
      'email': s.email,
      'ci': _ci ?? s.ci,
      'policyId': policyId,
      'startFormData': startFormData,
    });
    return body['code']?.toString() ?? '';
  }

  /// Inicia el trámite como cliente NUEVO: el correo + CI que escribió en
  /// el formulario son su identidad fundacional — el backend crea su
  /// registro de cliente y desde entonces puede ingresar con esos datos.
  Future<String> startCaseAsGuest(
    String policyId,
    Map<String, dynamic> startFormData, {
    required String email,
    required String ci,
  }) async {
    final body = await _postJson('$apiBase/start-case', {
      'email': email,
      'ci': ci,
      'policyId': policyId,
      'startFormData': startFormData,
    });
    return body['code']?.toString() ?? '';
  }

  // ── Notificaciones push ───────────────────────────────────────────────

  /// Registra el token FCM del dispositivo, atado al cliente logueado.
  Future<void> registerDeviceToken(String token) async {
    final s = _requireSession();
    await _postJson('$apiBase/device-token', {
      'email': s.email,
      'ci': _ci ?? s.ci,
      'token': token,
      'platform': 'android',
    });
  }

  /// Últimas notificaciones del cliente (campanita / historial).
  Future<List<MobileNotification>> getNotifications() async {
    final s = _requireSession();
    final uri = Uri.parse('$apiBase/notifications').replace(
      queryParameters: {'email': s.email, 'ci': _ci ?? s.ci},
    );
    final body = await _getJson(uri.toString());
    return (body as List)
        .whereType<Map<String, dynamic>>()
        .map(MobileNotification.fromJson)
        .toList();
  }

  /// Marca todas las notificaciones como leídas.
  Future<void> markNotificationsRead() async {
    final s = _requireSession();
    await _postJson('$apiBase/notifications/mark-read', {
      'email': s.email,
      'ci': _ci ?? s.ci,
    });
  }

  // ── Internals ─────────────────────────────────────────────────────────

  MobileSession _requireSession() {
    final s = session;
    if (s == null) {
      throw const ApiException(401, 'Sesión no iniciada.');
    }
    return s;
  }

  Future<dynamic> _getJson(String url) async {
    final http.Response res;
    try {
      res = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException(0, _connectionHint(url));
    }
    return _decode(res);
  }

  Future<dynamic> _postJson(String url, Map<String, dynamic> body) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      throw ApiException(0, _connectionHint(url));
    }
    return _decode(res);
  }

  /// Mensaje de error de conexión con la URL real intentada + la pista
  /// correcta según dónde corre la app.
  String _connectionHint(String url) {
    final uri = Uri.tryParse(url);
    final target = uri != null ? '${uri.host}:${uri.port}' : url;
    return 'No se pudo conectar con el servidor ($target). '
        'Si usas un teléfono físico, abre «Ajustes de conexión» en el '
        'login y escribe la IP de tu PC; verifica también que el backend '
        'esté corriendo.';
  }

  dynamic _decode(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    final dynamic body = text.isEmpty ? {} : jsonDecode(text);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    String message = 'Error del servidor (${res.statusCode}).';
    if (body is Map<String, dynamic>) {
      message = body['message']?.toString() ??
          body['detail']?.toString() ??
          message;
    }
    throw ApiException(res.statusCode, message);
  }
}

/// Instancia compartida de la app (sesión única del cliente).
final portal = PortalService();
