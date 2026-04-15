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

  static const List<Map<String, dynamic>> _mockRetos = [
    {
      'id': 1,
      'titulo': 'Recorre 10 km sin parar',
      'descripcion': 'Completa un recorrido continuo de al menos 10 km en Bogotá.',
      'tipo': 'distancia',
      'dificultad': 'facil',
      'meta_valor': 10,
      'meta_unidad': 'km',
      'mi_progreso': 10.0,
      'completado': true,
      'puntos_recompensa': 50,
    },
    {
      'id': 2,
      'titulo': 'Velocidad crucero',
      'descripcion': 'Mantén una velocidad promedio de 20 km/h durante toda una rodada.',
      'tipo': 'velocidad',
      'dificultad': 'medio',
      'meta_valor': 20,
      'meta_unidad': 'km/h',
      'mi_progreso': 16.5,
      'completado': false,
      'puntos_recompensa': 100,
    },
    {
      'id': 3,
      'titulo': 'Escalador urbano',
      'descripcion': 'Acumula 200 metros de desnivel positivo en una sola actividad.',
      'tipo': 'desnivel',
      'dificultad': 'dificil',
      'meta_valor': 200,
      'meta_unidad': 'm',
      'mi_progreso': 120.0,
      'completado': false,
      'puntos_recompensa': 200,
    },
    {
      'id': 4,
      'titulo': 'Explorador de POIs',
      'descripcion': 'Visita 3 puntos de interés ciclista en la ciudad.',
      'tipo': 'puntos_de_interes',
      'dificultad': 'facil',
      'meta_valor': 3,
      'meta_unidad': 'POIs',
      'mi_progreso': 3.0,
      'completado': true,
      'puntos_recompensa': 75,
    },
    {
      'id': 5,
      'titulo': 'Gran fondo',
      'descripcion': 'Completa una rodada de 30 km en menos de 2 horas.',
      'tipo': 'distancia',
      'dificultad': 'dificil',
      'meta_valor': 30,
      'meta_unidad': 'km',
      'mi_progreso': 12.3,
      'completado': false,
      'puntos_recompensa': 300,
    },
  ];

  static const Map<String, dynamic> _mockLeaderboard = {
    'mi_posicion': 7,
    'total_usuarios': 342,
    'entries': [
      {'posicion': 1, 'nombre': 'Andrés Pedraza',   'foto_url': null, 'puntos': 8420, 'nivel': 8, 'rango': 'Maestro del Asfalto',  'km_totales': 1240.5},
      {'posicion': 2, 'nombre': 'Valentina Cruz',   'foto_url': null, 'puntos': 7850, 'nivel': 7, 'rango': 'Ciclista Élite',       'km_totales': 1105.0},
      {'posicion': 3, 'nombre': 'Carlos Monsalve',  'foto_url': null, 'puntos': 6340, 'nivel': 7, 'rango': 'Ciclista Élite',       'km_totales':  980.3},
      {'posicion': 4, 'nombre': 'Luisa Fernanda',   'foto_url': null, 'puntos': 4210, 'nivel': 5, 'rango': 'Rodador Frecuente',    'km_totales':  620.8},
      {'posicion': 5, 'nombre': 'Juan Gómez',       'foto_url': null, 'puntos': 3100, 'nivel': 5, 'rango': 'Rodador Frecuente',    'km_totales':  455.2},
      {'posicion': 6, 'nombre': 'María Salcedo',    'foto_url': null, 'puntos': 1890, 'nivel': 4, 'rango': 'Ciclista Urbano',      'km_totales':  278.1},
      {'posicion': 7, 'nombre': 'Ciclista Demo',    'foto_url': null, 'puntos': 1250, 'nivel': 3, 'rango': 'Ciclista Avanzado',    'km_totales':  142.5},
      {'posicion': 8, 'nombre': 'Ricardo Herrera',  'foto_url': null, 'puntos':  980, 'nivel': 2, 'rango': 'Ciclista Novato',      'km_totales':   95.0},
      {'posicion': 9, 'nombre': 'Diana López',      'foto_url': null, 'puntos':  750, 'nivel': 2, 'rango': 'Ciclista Novato',      'km_totales':   72.4},
      {'posicion':10, 'nombre': 'Pablo Nieto',      'foto_url': null, 'puntos':  520, 'nivel': 1, 'rango': 'Pedaleando',           'km_totales':   45.0},
    ],
  };

  static const List<Map<String, dynamic>> _mockPois = [
    {
      'id': 'poi-001',
      'tipo': 'repair_shop',
      'nombre': 'Cicloservicio El Caño',
      'direccion': 'Calle 72 # 7-42, Chapinero',
      'descripcion': 'Taller especializado en bicicletas de ruta y montaña. Mantenimiento express.',
      'lat': 4.6497,
      'lng': -74.0556,
      'horario': 'Lun-Sáb 8am-6pm',
      'telefono': '310 555 0101',
      'rating_promedio': 4.7,
    },
    {
      'id': 'poi-002',
      'tipo': 'bike_store',
      'nombre': 'Trek Bogotá Norte',
      'direccion': 'Av. Chile # 11-27, Chapinero',
      'descripcion': 'Tienda oficial Trek. Venta, accesorios y repuestos originales.',
      'lat': 4.6580,
      'lng': -74.0530,
      'horario': 'Lun-Dom 9am-7pm',
      'telefono': '601 800 1234',
      'rating_promedio': 4.5,
    },
    {
      'id': 'poi-003',
      'tipo': 'parking',
      'nombre': 'Bicicletero Parque de la 93',
      'direccion': 'Parque de la 93, Usaquén',
      'descripcion': 'Bicicletero con candado y vigilancia. Capacidad 30 bicicletas.',
      'lat': 4.6762,
      'lng': -74.0484,
      'horario': '24 horas',
      'telefono': null,
      'rating_promedio': 4.2,
    },
    {
      'id': 'poi-004',
      'tipo': 'water_point',
      'nombre': 'Punto de agua Ciclovía Norte',
      'direccion': 'Carrera 7 con Calle 85',
      'descripcion': 'Bebedero gratuito con agua potable. Activo todos los domingos ciclovía.',
      'lat': 4.6693,
      'lng': -74.0507,
      'horario': 'Dom 7am-2pm',
      'telefono': null,
      'rating_promedio': 4.0,
    },
    {
      'id': 'poi-005',
      'tipo': 'rest_area',
      'nombre': 'Zona descanso Parque El Virrey',
      'direccion': 'Parque El Virrey, Calle 90',
      'descripcion': 'Bancas, sombra y baños públicos. Punto de encuentro de rodadores.',
      'lat': 4.6735,
      'lng': -74.0499,
      'horario': '6am-9pm',
      'telefono': null,
      'rating_promedio': 4.6,
    },
    {
      'id': 'poi-006',
      'tipo': 'bike_sharing',
      'nombre': 'Estación Tembici Usaquén',
      'direccion': 'Calle 116 # 15-10',
      'descripcion': 'Estación de bicicletas compartidas Tembici. 15 bicicletas disponibles.',
      'lat': 4.6941,
      'lng': -74.0437,
      'horario': '24 horas',
      'telefono': null,
      'rating_promedio': 4.1,
    },
    {
      'id': 'poi-007',
      'tipo': 'repair_shop',
      'nombre': 'Taller Rueda Libre',
      'direccion': 'Carrera 13 # 63-41, Chapinero',
      'descripcion': 'Reparaciones rápidas, inflado gratis, ajuste de cambios y frenos.',
      'lat': 4.6441,
      'lng': -74.0572,
      'horario': 'Lun-Vie 9am-5pm',
      'telefono': '315 444 9988',
      'rating_promedio': 4.3,
    },
    {
      'id': 'poi-008',
      'tipo': 'parking',
      'nombre': 'Bicicletero Centro Comercial Andino',
      'direccion': 'CC Andino, Carrera 11 # 82-71',
      'descripcion': 'Parqueadero cubierto y vigilado en sótano. Acceso desde Calle 82.',
      'lat': 4.6661,
      'lng': -74.0528,
      'horario': 'Lun-Dom 10am-9pm',
      'telefono': null,
      'rating_promedio': 3.9,
    },
  ];

  static const List<Map<String, dynamic>> _mockContribuciones = [
    {
      'id': 101,
      'tipo': 'hazard',
      'descripcion': 'Hueco profundo en la ciclovía de la Calle 26 a la altura de la carrera 30.',
      'estado': 'approved',
      'lat': 4.6297,
      'lng': -74.1017,
      'votos_positivos': 12,
      'votos_negativos': 1,
      'foto_url': null,
      'created_at': '2024-10-15T09:30:00Z',
    },
    {
      'id': 102,
      'tipo': 'route_update',
      'descripcion': 'Nuevo tramo de ciclovía habilitado en la Av. Boyacá entre calles 80 y 100.',
      'estado': 'approved',
      'lat': 4.7012,
      'lng': -74.0897,
      'votos_positivos': 24,
      'votos_negativos': 0,
      'foto_url': null,
      'created_at': '2024-10-20T14:00:00Z',
    },
    {
      'id': 103,
      'tipo': 'poi_add',
      'descripcion': 'Bicicletero nuevo en el Parque Nacional con capacidad para 20 bicicletas.',
      'estado': 'pending',
      'lat': 4.6151,
      'lng': -74.0722,
      'votos_positivos': 5,
      'votos_negativos': 0,
      'foto_url': null,
      'created_at': '2024-11-01T11:00:00Z',
    },
    {
      'id': 104,
      'tipo': 'road_closed',
      'descripcion': 'Cierre temporal de la ciclovía del Parque Simón Bolívar por obras de mantenimiento.',
      'estado': 'stale',
      'lat': 4.6582,
      'lng': -74.0961,
      'votos_positivos': 8,
      'votos_negativos': 3,
      'foto_url': null,
      'created_at': '2024-09-10T08:00:00Z',
    },
  ];

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
    if (await esModoDemo) {
      return tipo == null || tipo.isEmpty
          ? List<Map<String, dynamic>>.from(_mockPois)
          : _mockPois.where((p) => p['tipo'] == tipo).toList();
    }
    final params = <String, dynamic>{'city': city};
    if (tipo != null) params['tipo'] = tipo;
    final response = await get<Map<String, dynamic>>('/pois', queryParams: params);
    return (response.data!['items'] as List?) ?? [];
  }

  /// Lista los retos del día.
  Future<List<dynamic>> listarRetos(String city) async {
    if (await esModoDemo) return List<Map<String, dynamic>>.from(_mockRetos);
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
    if (await esModoDemo) {
      final items = estado == null || estado.isEmpty
          ? _mockContribuciones
          : _mockContribuciones.where((c) => c['estado'] == estado).toList();
      return {'items': List<Map<String, dynamic>>.from(items), 'total': items.length};
    }
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
    if (await esModoDemo) return Map<String, dynamic>.from(_mockLeaderboard);
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
    if (await esModoDemo) {
      return tipo == null || tipo.isEmpty
          ? List<Map<String, dynamic>>.from(_mockPois)
          : _mockPois.where((p) => p['tipo'] == tipo).toList();
    }
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
