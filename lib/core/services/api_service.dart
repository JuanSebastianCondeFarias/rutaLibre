// apps/mobile/lib/core/services/api_service.dart
// Cliente HTTP Dio para comunicarse con el backend de RutaLibre

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;

import '../../features/community_routes/models/community_route_model.dart';

/// Servicio HTTP centralizado para todas las llamadas al backend.
class ApiService {
  static String get _baseUrl {
    // En web usa 127.0.0.1 en lugar de localhost para evitar problemas de CORS
    if (kIsWeb) return 'http://127.0.0.1:8000';
    // Variable de entorno tiene prioridad (CI, staging, producción)
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Android emulator: 10.0.2.2 es el alias de localhost del host
    // iOS simulator y macOS: localhost es accesible directamente
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  // ─── Usuario demo (sin backend) ────────────────────────────
  static const String _mockToken = 'mock_demo_v1';

  static const Map<String, dynamic> _mockUserData = {
    'id': 'demo-001',
    'nombre': 'Ciclista Demo',
    'email': 'demo@rutalibre.co',
    'foto_url': null,
    'nivel': 3,
    'rango': 'Ciclista Avanzado',
    'puntos': 1250,
    'puntos_para_subir': 2000,
    'km_totales': 142.5,
    'rutas_completadas': 12,
    'retos_completados': 5,
    'contribuciones_aprobadas': 8,
    'created_at': '2024-09-01T00:00:00Z',
  };

  final FlutterSecureStorage _storage;
  late final Dio _dio;

  ApiService(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Interceptor para agregar token JWT
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Intentar refresh si el token expiró
        if (error.response?.statusCode == 401) {
          final refrescado = await _intentarRefresh();
          if (refrescado) {
            // Reintentar la petición original
            final opts = error.requestOptions;
            final token = await _storage.read(key: _tokenKey);
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.request(
                opts.path,
                options: Options(method: opts.method, headers: opts.headers),
                data: opts.data,
                queryParameters: opts.queryParameters,
              );
              return handler.resolve(response);
            } catch (e) {
              return handler.reject(error);
            }
          }
        }
        return handler.next(error);
      },
    ));

    // Logging en debug
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (log) => debugPrint('[API] $log'),
      ));
    }
  }

  /// Intenta refrescar el access token usando el refresh token.
  Future<bool> _intentarRefresh() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) return false;

    try {
      final response = await Dio().post(
        '$_baseUrl/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      await _storage.write(key: _tokenKey, value: response.data['access_token']);
      await _storage.write(key: _refreshTokenKey, value: response.data['refresh_token']);
      return true;
    } catch (_) {
      // Refresh falló — limpiar tokens
      await cerrarSesion();
      return false;
    }
  }

  Future<void> cerrarSesion() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> get estaAutenticado async {
    final token = await _storage.read(key: _tokenKey);
    return token != null;
  }

  /// Inicia sesión con el usuario demo local (sin backend).
  Future<void> loginComoDemo() async {
    await _storage.write(key: _tokenKey, value: _mockToken);
    await _storage.write(key: _refreshTokenKey, value: 'mock_refresh_v1');
  }

  /// True si la sesión activa es la del usuario demo.
  Future<bool> get esModoDemo async {
    final token = await _storage.read(key: _tokenKey);
    return token == _mockToken;
  }

  // ─── Métodos HTTP genéricos ─────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParams,
    Options? options,
  }) => _dio.get<T>(path, queryParameters: queryParams, options: options);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    Options? options,
  }) => _dio.post<T>(path, data: data, queryParameters: queryParams, options: options);

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) => _dio.patch<T>(path, data: data, options: options);

  // ─── Métodos de dominio ─────────────────────────────────────

  /// Calcula una ruta para bicicleta.
  Future<Map<String, dynamic>> calcularRuta({
    required String city,
    required List<double> origin,
    required List<double> destination,
    String perfil = 'bike',
  }) async {
    final response = await post<Map<String, dynamic>>(
      '/routes',
      queryParams: {'city': city},
      data: {
        'origin': origin,
        'destination': destination,
        'perfil': perfil,
      },
    );
    return response.data!;
  }

  /// Lista POIs de una ciudad.
  Future<List<dynamic>> listarPois(String city, {String? tipo}) async {
    final params = <String, dynamic>{'city': city};
    if (tipo != null) params['tipo'] = tipo;
    final response = await get<Map<String, dynamic>>('/pois', queryParams: params);
    return (response.data!['items'] as List?) ?? [];
  }

  /// Lista los retos del día.
  Future<List<dynamic>> listarRetos(String city) async {
    final response = await get<List<dynamic>>(
      '/challenges',
      queryParams: {'city': city},
    );
    return response.data ?? [];
  }

  /// Obtiene el perfil del usuario autenticado.
  /// Devuelve datos mock si la sesión es demo.
  Future<Map<String, dynamic>> miPerfil() async {
    if (await esModoDemo) return Map<String, dynamic>.from(_mockUserData);
    final response = await get<Map<String, dynamic>>('/users/me');
    return response.data!;
  }

  /// Crea una contribución con foto opcional.
  Future<Map<String, dynamic>> crearContribucion({
    required String city,
    required String tipo,
    required String descripcion,
    required double lat,
    required double lng,
    File? foto,
  }) async {
    final formData = FormData.fromMap({
      'tipo': tipo,
      'descripcion': descripcion,
      'lat': lat.toString(),
      'lng': lng.toString(),
      if (foto != null)
        'foto': await MultipartFile.fromFile(
          foto.path,
          filename: foto.path.split('/').last,
        ),
    });

    final response = await post<Map<String, dynamic>>(
      '/contributions',
      queryParams: {'city': city},
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data!;
  }

  /// Lista contribuciones de una ciudad con filtro de estado opcional.
  Future<Map<String, dynamic>> listarContribuciones(
    String city, {
    String? estado,
  }) async {
    final params = <String, dynamic>{'city': city};
    if (estado != null && estado.isNotEmpty) params['estado'] = estado;
    final response = await get<Map<String, dynamic>>(
      '/contributions',
      queryParams: params,
    );
    return response.data!;
  }

  /// Vota en una contribución (positivo o negativo).
  Future<Map<String, dynamic>> votarContribucion(
    String city,
    int id,
    bool esPositivo,
  ) async {
    final response = await post<Map<String, dynamic>>(
      '/contributions/$id/vote',
      queryParams: {'city': city},
      data: {'es_positivo': esPositivo},
    );
    return response.data!;
  }

  /// Obtiene el leaderboard de una ciudad.
  Future<Map<String, dynamic>> leaderboard(String city, {int limite = 20}) async {
    final response = await get<Map<String, dynamic>>(
      '/challenges/leaderboard',
      queryParams: {'city': city, 'limit': limite},
    );
    return response.data!;
  }

  /// Lista POIs con geolocalización por radio.
  Future<List<dynamic>> listarPoisConUbicacion(
    String city, {
    String? tipo,
    double? lat,
    double? lng,
    double? radioKm,
  }) async {
    final params = <String, dynamic>{'city': city};
    if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
    if (lat != null) params['lat'] = lat;
    if (lng != null) params['lng'] = lng;
    if (radioKm != null) params['radio_km'] = radioKm;
    final response = await get<Map<String, dynamic>>('/pois', queryParams: params);
    return (response.data!['items'] as List?) ?? [];
  }

  /// Lista ciudades disponibles.
  Future<List<dynamic>> listarCiudades() async {
    final response = await get<List<dynamic>>('/cities');
    return response.data ?? [];
  }

  /// Obtiene configuración de una ciudad.
  Future<Map<String, dynamic>> obtenerCiudad(String slug) async {
    final response = await get<Map<String, dynamic>>('/cities/$slug');
    return response.data!;
  }

  /// Inicia autenticación OAuth con Google.
  String get urlAuthGoogle => '$_baseUrl/auth/google';

  /// Guarda tokens después del callback OAuth.
  Future<void> guardarTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _tokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  // ─── Rutas de la comunidad ──────────────────────────────────

  /// Lista rutas publicadas por la comunidad para una ciudad.
  /// Acepta filtro opcional por dificultad: 'facil', 'moderado' o 'dificil'.
  Future<List<CommunityRouteModel>> listarRutasComunidad(
    String city, {
    String? dificultad,
  }) async {
    final params = <String, dynamic>{'city': city};
    if (dificultad != null && dificultad.isNotEmpty) {
      params['dificultad'] = dificultad;
    }
    final response = await get<Map<String, dynamic>>(
      '/community-routes',
      queryParams: params,
    );
    final items = (response.data!['items'] as List?) ?? [];
    return items
        .map((e) => CommunityRouteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Publica una ruta nueva de la comunidad.
  /// El campo [data] debe incluir: title, difficulty y points como mínimo.
  Future<Map<String, dynamic>> publicarRutaComunidad({
    required String city,
    required Map<String, dynamic> data,
  }) async {
    final response = await post<Map<String, dynamic>>(
      '/community-routes',
      queryParams: {'city': city},
      data: data,
    );
    return response.data!;
  }

  /// Envía una calificación (1 a 5) para una ruta de la comunidad.
  Future<void> calificarRuta(String city, int routeId, double rating) async {
    await post<void>(
      '/community-routes/$routeId/ratings',
      queryParams: {'city': city},
      data: {'rating': rating},
    );
  }
}
