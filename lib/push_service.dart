import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'portal_service.dart';

/// Handler de mensajes con la app TERMINADA o en segundo plano.
/// Debe ser una función top-level (la VM lo invoca en un isolate aparte).
/// FCM ya pinta la notificación del sistema en background/terminated, así
/// que aquí no hay que hacer nada — el hook existe para futuros usos
/// (badges, sincronización silenciosa).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Notificaciones push del portal del cliente (Firebase Cloud Messaging).
///
/// Eventos que envía el backend:
///   - CASE_STARTED   → su trámite quedó registrado.
///   - AREA_CHANGED   → el trámite pasó a otra área/departamento.
///   - CASE_FINISHED  → el trámite finalizó.
///
/// Diseño tolerante: si `google-services.json` no está configurado todavía,
/// `init()` falla en silencio y la app funciona igual (la campanita sigue
/// mostrando el historial desde el backend).
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  bool _available = false;
  bool get isAvailable => _available;

  /// Avisa a la UI cuando llega un push con la app abierta (para refrescar
  /// la campanita / dashboard sin que el usuario haga pull-to-refresh).
  void Function()? onNotificationReceived;

  /// Inicializa Firebase + canal local. Llamar UNA vez antes de runApp.
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      // Canal Android (debe coincidir con el channelId que envía el backend).
      const channel = AndroidNotificationChannel(
        'tramites',
        'Avances de trámites',
        description: 'Avisos cuando tu trámite inicia, cambia de área o finaliza.',
        importance: Importance.high,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      // Con la app en PRIMER plano FCM no pinta la notificación: la
      // mostramos nosotros con flutter_local_notifications.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          _local.show(
            notification.hashCode,
            notification.title,
            notification.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'tramites',
                'Avances de trámites',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
        onNotificationReceived?.call();
      });

      _available = true;
    } catch (e) {
      // Sin google-services.json (o en plataformas no configuradas) la app
      // sigue funcionando — solo sin push.
      // ignore: avoid_print
      print('[push] Firebase no disponible: $e');
      _available = false;
    }
  }

  /// Pide permiso (Android 13+) y registra el token del dispositivo en el
  /// backend, atado al cliente de la sesión. Llamar tras el login.
  Future<void> registerWithBackend() async {
    if (!_available || !portal.isLoggedIn) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await portal.registerDeviceToken(token);
      }
      // Si FCM rota el token, re-registramos al instante.
      messaging.onTokenRefresh.listen((newToken) {
        if (portal.isLoggedIn) {
          portal.registerDeviceToken(newToken).catchError((_) {});
        }
      });
    } catch (e) {
      // ignore: avoid_print
      print('[push] No se pudo registrar el token: $e');
    }
  }
}
