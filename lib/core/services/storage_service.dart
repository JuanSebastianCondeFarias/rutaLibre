// apps/mobile/lib/core/services/storage_service.dart
// Almacenamiento local con SharedPreferences

import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de almacenamiento local para preferencias del usuario.
class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // Claves de almacenamiento
  static const String _ciudadKey = 'ciudad_seleccionada';
  static const String _temaKey = 'tema';
  static const String _idiomaKey = 'idioma';
  static const String _notificacionesKey = 'notificaciones';

  // ─── Ciudad ────────────────────────────────────────────────

  String get ciudadSeleccionada => _prefs.getString(_ciudadKey) ?? 'bogota';

  Future<void> setCiudad(String slug) => _prefs.setString(_ciudadKey, slug);

  // ─── Tema ──────────────────────────────────────────────────

  String get tema => _prefs.getString(_temaKey) ?? 'system';

  Future<void> setTema(String modo) => _prefs.setString(_temaKey, modo);

  // ─── Idioma ────────────────────────────────────────────────

  String get idioma => _prefs.getString(_idiomaKey) ?? 'es-CO';

  Future<void> setIdioma(String locale) => _prefs.setString(_idiomaKey, locale);

  // ─── Notificaciones ────────────────────────────────────────

  bool get notificacionesActivas => _prefs.getBool(_notificacionesKey) ?? false;

  Future<void> setNotificaciones(bool activo) =>
      _prefs.setBool(_notificacionesKey, activo);

  // ─── Cache de rutas recientes ──────────────────────────────

  List<String> get rutasRecientes =>
      _prefs.getStringList('rutas_recientes') ?? [];

  Future<void> agregarRutaReciente(String rutalJson) async {
    final lista = rutasRecientes;
    lista.insert(0, rutalJson);
    // Máximo 10 rutas recientes
    if (lista.length > 10) lista.removeLast();
    await _prefs.setStringList('rutas_recientes', lista);
  }

  // ─── Sesión ────────────────────────────────────────────────

  Future<void> limpiarTodo() => _prefs.clear();
}
