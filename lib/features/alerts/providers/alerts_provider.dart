// apps/mobile/lib/features/alerts/providers/alerts_provider.dart
// Provider que gestiona preferencias de alertas y zonas del usuario

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/notification_service.dart';
import '../models/user_zone_model.dart';

/// ChangeNotifier que centraliza el estado de alertas personalizadas:
/// - Toggles de notificaciones (peligros, ciclovía)
/// - Lista de zonas de alerta geográficas (máx 5)
/// - Persistencia en SharedPreferences
class AlertsProvider extends ChangeNotifier {
  // ─── Claves de almacenamiento ──────────────────────────────────
  static const String _keyZonas = 'zonas_alerta';
  static const String _keyPeligros = 'notif_peligros';
  static const String _keyCiclovia = 'notif_ciclovia';

  /// Máximo de zonas de alerta permitidas por usuario.
  static const int maxZonas = 5;

  final SharedPreferences _prefs;

  /// Ciudad activa. Se usa para suscribir/desuscribir topics correctos.
  String _citySlug;

  // ─── Estado ─────────────────────────────────────────────────────
  List<UserZoneModel> _zonas = [];
  bool _peligrosActivos = true;
  bool _cicloviaActiva = true;

  // ─── Getters públicos ──────────────────────────────────────────
  List<UserZoneModel> get zonas => List.unmodifiable(_zonas);
  bool get peligrosActivos => _peligrosActivos;
  bool get cicloviaActiva => _cicloviaActiva;
  bool get puedeAgregarZona => _zonas.length < maxZonas;
  String get citySlug => _citySlug;

  AlertsProvider(this._prefs, {String citySlug = 'bogota'})
      : _citySlug = citySlug {
    _cargarDesdePrefs();
  }

  // ─── Carga inicial ─────────────────────────────────────────────

  /// Lee el estado guardado de SharedPreferences al arrancar.
  void _cargarDesdePrefs() {
    // Preferencias booleanas
    _peligrosActivos = _prefs.getBool(_keyPeligros) ?? true;
    _cicloviaActiva = _prefs.getBool(_keyCiclovia) ?? true;

    // Zonas guardadas como lista de strings JSON
    final listaJson = _prefs.getStringList(_keyZonas) ?? [];
    _zonas = listaJson.map((s) {
      try {
        return UserZoneModel.fromJsonString(s);
      } catch (e) {
        debugPrint('[AlertsProvider] Error parseando zona: $e');
        return null;
      }
    }).whereType<UserZoneModel>().toList();
  }

  // ─── Cambio de ciudad ──────────────────────────────────────────

  /// Actualiza la ciudad activa y reajusta las suscripciones FCM.
  Future<void> cambiarCiudad(String nuevoSlug) async {
    if (nuevoSlug == _citySlug) return;

    final notif = NotificationService.instance;

    // Desuscribir de la ciudad anterior
    if (_peligrosActivos) await notif.desuscribirPeligros(_citySlug);
    if (_cicloviaActiva) await notif.desuscribirCiclovia(_citySlug);

    _citySlug = nuevoSlug;

    // Suscribir a la nueva ciudad según preferencias activas
    if (_peligrosActivos) await notif.suscribirPeligros(_citySlug);
    if (_cicloviaActiva) await notif.suscribirCiclovia(_citySlug);

    notifyListeners();
  }

  // ─── Toggles de notificaciones ─────────────────────────────────

  /// Activa o desactiva las notificaciones de peligros en la ciudad activa.
  Future<void> togglePeligros() async {
    _peligrosActivos = !_peligrosActivos;
    await _prefs.setBool(_keyPeligros, _peligrosActivos);

    final notif = NotificationService.instance;
    if (_peligrosActivos) {
      await notif.suscribirPeligros(_citySlug);
    } else {
      await notif.desuscribirPeligros(_citySlug);
    }

    notifyListeners();
  }

  /// Activa o desactiva las notificaciones de ciclovía en la ciudad activa.
  Future<void> toggleCiclovia() async {
    _cicloviaActiva = !_cicloviaActiva;
    await _prefs.setBool(_keyCiclovia, _cicloviaActiva);

    final notif = NotificationService.instance;
    if (_cicloviaActiva) {
      await notif.suscribirCiclovia(_citySlug);
    } else {
      await notif.desuscribirCiclovia(_citySlug);
    }

    notifyListeners();
  }

  // ─── Gestión de zonas ──────────────────────────────────────────

  /// Agrega una nueva zona de alerta. No permite superar [maxZonas].
  Future<void> agregarZona(UserZoneModel zona) async {
    if (_zonas.length >= maxZonas) return;

    _zonas.add(zona);
    await _persistirZonas();
    notifyListeners();
  }

  /// Elimina una zona de alerta por su id.
  Future<void> eliminarZona(String id) async {
    _zonas.removeWhere((z) => z.id == id);
    await _persistirZonas();
    notifyListeners();
  }

  // ─── Persistencia interna ───────────────────────────────────────

  Future<void> _persistirZonas() async {
    final listaJson = _zonas.map((z) => z.toJsonString()).toList();
    await _prefs.setStringList(_keyZonas, listaJson);
  }
}
