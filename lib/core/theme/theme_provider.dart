// apps/mobile/lib/core/theme/theme_provider.dart
// Provider del tema claro/oscuro con persistencia en SharedPreferences

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el tema de la aplicación y lo persiste en almacenamiento local.
class ThemeProvider extends ChangeNotifier {
  static const String _clave = 'rutalibre_theme';

  final SharedPreferences _prefs;
  late ThemeMode _themeMode;

  ThemeProvider(this._prefs) {
    // Cargar tema guardado
    final guardado = _prefs.getString(_clave);
    _themeMode = _fromString(guardado);
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLight => _themeMode == ThemeMode.light;
  bool get isSystem => _themeMode == ThemeMode.system;

  /// Cambia al tema especificado y lo persiste.
  Future<void> setTheme(ThemeMode modo) async {
    if (_themeMode == modo) return;
    _themeMode = modo;
    await _prefs.setString(_clave, _toString(modo));
    notifyListeners();
  }

  /// Alterna entre tema claro y oscuro.
  Future<void> toggleTheme() async {
    final nuevoModo = isDark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(nuevoModo);
  }

  /// Usa el tema del sistema operativo.
  Future<void> useSystemTheme() async {
    await setTheme(ThemeMode.system);
  }

  static ThemeMode _fromString(String? valor) {
    switch (valor) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode modo) {
    switch (modo) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
