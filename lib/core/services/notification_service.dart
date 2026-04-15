// apps/mobile/lib/core/services/notification_service.dart
// Servicio singleton de notificaciones push con Firebase Messaging

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

/// Manejador de mensajes en background/terminated (debe ser top-level).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase ya está inicializado por el isolate de background
  debugPrint('[FCM] Mensaje en background: ${message.messageId}');
}

/// Singleton que gestiona permisos, token FCM, suscripción a topics
/// y el ruteo de notificaciones entrantes.
class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  /// Acceso global al singleton.
  static NotificationService get instance => _instance;

  late final FirebaseMessaging _messaging;
  bool _firebaseAvailable = false;

  String? _fcmToken;

  /// Token FCM actual del dispositivo. Puede ser null si Firebase no está listo.
  String? get fcmToken => _fcmToken;

  // Navegador global para enrutar desde notificaciones
  static GlobalKey<NavigatorState>? navigatorKey;

  // ─── Inicialización ────────────────────────────────────────────

  /// Inicializa permisos, token y handlers de mensajes.
  /// Debe llamarse una sola vez, después de Firebase.initializeApp().
  /// Si Firebase no está disponible, la app continúa sin notificaciones.
  Future<void> initialize() async {
    try {
      // Intentar acceder a FirebaseMessaging — falla si Firebase no está inicializado
      _messaging = FirebaseMessaging.instance;
      _firebaseAvailable = true;
    } catch (e) {
      debugPrint('[FCM] Firebase no disponible: $e — notificaciones deshabilitadas');
      return; // Continuar sin Firebase
    }

    try {
      // Registrar handler de background antes de cualquier otra cosa
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      // Solicitar permiso (iOS lo muestra como diálogo; Android ≥13 también)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
        '[FCM] Estado de permiso: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // Usuario rechazó — no configurar handlers (no hay notificaciones)
        return;
      }

      // Obtener token inicial
      await _refrescarToken();

      // Escuchar renovaciones de token (ej. cuando el usuario reinstala la app)
      _messaging.onTokenRefresh.listen((nuevoToken) {
        debugPrint('[FCM] Token renovado');
        _fcmToken = nuevoToken;
      });

      // Mensajes en foreground → banner in-app via SnackBar
      FirebaseMessaging.onMessage.listen(_manejarMensajeForeground);

      // App abierta desde notificación (estaba en background)
      FirebaseMessaging.onMessageOpenedApp.listen(_manejarAperturaDesdeNotificacion);

      // App abierta desde terminated — verificar si hay mensaje inicial
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        // Pequeño delay para asegurar que el navigator esté montado
        await Future.delayed(const Duration(milliseconds: 500));
        _manejarAperturaDesdeNotificacion(initialMessage);
      }
    } catch (e) {
      debugPrint('[FCM] Error durante inicialización: $e');
      _firebaseAvailable = false;
    }
  }

  // ─── Handlers ──────────────────────────────────────────────────

  /// Muestra un SnackBar con el mensaje cuando la app está en primer plano.
  void _manejarMensajeForeground(RemoteMessage message) {
    debugPrint('[FCM] Mensaje en foreground: ${message.notification?.title}');

    final context = navigatorKey?.currentContext;
    if (context == null) return;

    final notification = message.notification;
    if (notification == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notification.title != null)
                    Text(
                      notification.title!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  if (notification.body != null)
                    Text(
                      notification.body!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF16A34A),
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: () => _navegar(message),
        ),
      ),
    );
  }

  /// Navega a la pantalla correcta según el tipo de notificación.
  void _manejarAperturaDesdeNotificacion(RemoteMessage message) {
    debugPrint('[FCM] App abierta desde notificación tipo: ${message.data['type']}');
    _navegar(message);
  }

  /// Determina la ruta destino según el campo `type` del payload.
  void _navegar(RemoteMessage message) {
    final tipo = message.data['type'] as String?;
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;

    switch (tipo) {
      case 'hazard':
      case 'road_closed':
        // Navegar al mapa para mostrar el peligro
        navigator.pushNamed('/');
        break;
      case 'contribution_approved':
      case 'contribution_rejected':
        navigator.pushNamed('/contribuciones');
        break;
      case 'ciclovia':
        navigator.pushNamed('/');
        break;
      default:
        // Tipo desconocido — ir al mapa por defecto
        navigator.pushNamed('/');
    }
  }

  // ─── Subscripción a topics ─────────────────────────────────────

  /// Suscribe el dispositivo a los topics de peligros y ciclovía de una ciudad.
  Future<void> suscribirCiudad(String slug) async {
    if (!_firebaseAvailable) return;
    try {
      await _messaging.subscribeToTopic('peligros_$slug');
      await _messaging.subscribeToTopic('ciclovia_$slug');
      debugPrint('[FCM] Suscrito a topics de ciudad: $slug');
    } catch (e) {
      debugPrint('[FCM] Error al suscribir ciudad $slug: $e');
    }
  }

  /// Desuscribe el dispositivo de los topics de una ciudad anterior.
  Future<void> desuscribirCiudad(String slug) async {
    if (!_firebaseAvailable) return;
    try {
      await _messaging.unsubscribeFromTopic('peligros_$slug');
      await _messaging.unsubscribeFromTopic('ciclovia_$slug');
      debugPrint('[FCM] Desuscrito de topics de ciudad: $slug');
    } catch (e) {
      debugPrint('[FCM] Error al desuscribir ciudad $slug: $e');
    }
  }

  /// Suscribe a peligros de una ciudad (canal granular).
  Future<void> suscribirPeligros(String slug) async {
    if (!_firebaseAvailable) return;
    try {
      await _messaging.subscribeToTopic('peligros_$slug');
      debugPrint('[FCM] Suscrito a peligros_$slug');
    } catch (e) {
      debugPrint('[FCM] Error suscribiendo peligros_$slug: $e');
    }
  }

  /// Desuscribe de peligros de una ciudad.
  Future<void> desuscribirPeligros(String slug) async {
    if (!_firebaseAvailable) return;
    try {
      await _messaging.unsubscribeFromTopic('peligros_$slug');
    } catch (e) {
      debugPrint('[FCM] Error desuscribiendo peligros_$slug: $e');
    }
  }

  /// Suscribe a notificaciones de ciclovía de una ciudad.
  Future<void> suscribirCiclovia(String slug) async {
    if (!_firebaseAvailable) return;
    try {
      await _messaging.subscribeToTopic('ciclovia_$slug');
      debugPrint('[FCM] Suscrito a ciclovia_$slug');
    } catch (e) {
      debugPrint('[FCM] Error suscribiendo ciclovia_$slug: $e');
    }
  }

  /// Desuscribe de notificaciones de ciclovía de una ciudad.
  Future<void> desuscribirCiclovia(String slug) async {
    if (!_firebaseAvailable) return;
    try {
      await _messaging.unsubscribeFromTopic('ciclovia_$slug');
    } catch (e) {
      debugPrint('[FCM] Error desuscribiendo ciclovia_$slug: $e');
    }
  }

  // ─── Token FCM ─────────────────────────────────────────────────

  /// Obtiene el token actual y lo almacena internamente.
  Future<void> _refrescarToken() async {
    if (!_firebaseAvailable) return;
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('[FCM] Token obtenido: ${_fcmToken?.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[FCM] Error obteniendo token: $e');
    }
  }

  /// Envía el token FCM al backend asociado a una ciudad.
  /// POST /users/fcm-token?city={slug}
  Future<void> saveFcmToken(String city) async {
    final token = _fcmToken;
    if (token == null) return;

    try {
      final apiService = ApiService(const FlutterSecureStorage());
      await apiService.post<void>(
        '/users/fcm-token',
        queryParams: {'city': city},
        data: {'token': token},
      );
      debugPrint('[FCM] Token guardado en backend para ciudad: $city');
    } catch (e) {
      // No es crítico si falla — se reintentará en la próxima sesión
      debugPrint('[FCM] Error guardando token en backend: $e');
    }
  }
}
