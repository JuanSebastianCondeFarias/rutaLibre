// apps/mobile/lib/features/routes/screens/route_calculator_screen.dart
// Calculadora de rutas con búsqueda de dirección y seguimiento en tiempo real

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../map/widgets/route_display_widget.dart';

/// Pantalla de calculadora de rutas con geocodificación y navegación.
class RouteCalculatorScreen extends StatefulWidget {
  const RouteCalculatorScreen({super.key});

  @override
  State<RouteCalculatorScreen> createState() => _RouteCalculatorScreenState();
}

class _RouteCalculatorScreenState extends State<RouteCalculatorScreen> {
  final _origenCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  final MapController _mapController = MapController();
  final GeocodingService _geocoding = GeocodingService(
    geoapifyKey: const String.fromEnvironment('GEOAPIFY_KEY', defaultValue: ''),
  );
  final LocationService _locationService = LocationService();

  String _perfil = 'bike';
  bool _calculando = false;
  Map<String, dynamic>? _ruta;
  String? _error;

  // Coordenadas seleccionadas
  LatLng? _origenCoords;
  LatLng? _destinoCoords;
  String? _origenNombre;
  String? _destinoNombre;

  // Sugerencias de geocodificación
  List<ResultadoBusqueda> _sugerenciasOrigen = [];
  List<ResultadoBusqueda> _sugerenciasDestino = [];
  bool _buscandoOrigen = false;
  bool _buscandoDestino = false;
  bool _sinResultadosOrigen = false;
  bool _sinResultadosDestino = false;
  Timer? _debounceOrigen;
  Timer? _debounceDestino;

  // Navegación en tiempo real
  bool _navegando = false;
  LatLng? _posicionActual;
  double? _heading;
  double? _speed;
  StreamSubscription<Position>? _positionSub;

  static const _perfiles = [
    {'value': 'bike', 'label': 'Estándar', 'emoji': '🚲', 'desc': 'Equilibrio entre velocidad y seguridad'},
    {'value': 'bike_safe', 'label': 'Seguro', 'emoji': '🛡️', 'desc': 'Máxima preferencia por ciclovías'},
    {'value': 'mtb', 'label': 'MTB', 'emoji': '🏔️', 'desc': 'Acepta caminos sin pavimentar'},
  ];

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionInicial();
  }

  @override
  void dispose() {
    _origenCtrl.dispose();
    _destinoCtrl.dispose();
    _debounceOrigen?.cancel();
    _debounceDestino?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _obtenerUbicacionInicial() async {
    try {
      final pos = await _locationService.obtenerUbicacionActual();
      if (mounted && _origenCoords == null) {
        final latLng = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _origenCoords = latLng;
          _origenNombre = 'Mi ubicación actual';
          _origenCtrl.text = 'Mi ubicación actual';
        });
        // Mover el mapa a la ubicación del usuario, igual que en la sección de mapa
        _mapController.move(latLng, 15);
      }
    } catch (_) {
      // No bloquear si no hay permisos
    }
  }

  void _buscarOrigen(String texto) {
    setState(() => _sinResultadosOrigen = false);
    _debounceOrigen?.cancel();
    if (texto.length < 3) {
      setState(() => _sugerenciasOrigen = []);
      return;
    }
    _debounceOrigen = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _buscandoOrigen = true);
      try {
        final res = await _geocoding.buscarDireccion(texto);
        if (mounted) {
          setState(() {
            _sugerenciasOrigen = res;
            _sinResultadosOrigen = res.isEmpty;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _sinResultadosOrigen = true);
      } finally {
        if (mounted) setState(() => _buscandoOrigen = false);
      }
    });
  }

  void _buscarDestino(String texto) {
    setState(() => _sinResultadosDestino = false);
    _debounceDestino?.cancel();
    if (texto.length < 3) {
      setState(() => _sugerenciasDestino = []);
      return;
    }
    _debounceDestino = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _buscandoDestino = true);
      try {
        final res = await _geocoding.buscarDireccion(texto);
        if (mounted) {
          setState(() {
            _sugerenciasDestino = res;
            _sinResultadosDestino = res.isEmpty;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _sinResultadosDestino = true);
      } finally {
        if (mounted) setState(() => _buscandoDestino = false);
      }
    });
  }

  void _seleccionarOrigen(ResultadoBusqueda r) {
    setState(() {
      _origenCoords = LatLng(r.lat, r.lon);
      _origenNombre = r.nombre;
      _origenCtrl.text = r.nombre;
      _sugerenciasOrigen = [];
      _sinResultadosOrigen = false;
    });
  }

  void _seleccionarDestino(ResultadoBusqueda r) {
    setState(() {
      _destinoCoords = LatLng(r.lat, r.lon);
      _destinoNombre = r.nombre;
      _destinoCtrl.text = r.nombre;
      _sugerenciasDestino = [];
      _sinResultadosDestino = false;
    });
  }

  Future<void> _usarUbicacionOrigen() async {
    try {
      final pos = await _locationService.obtenerUbicacionActual();
      if (!mounted) return;
      setState(() {
        _origenCoords = LatLng(pos.latitude, pos.longitude);
        _origenNombre = 'Mi ubicación actual';
        _origenCtrl.text = 'Mi ubicación actual';
        _sugerenciasOrigen = [];
      });
      // Centrar mapa en la ubicación obtenida
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } on LocationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 ${e.mensaje}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 No se pudo obtener tu ubicación. Activa el GPS e intenta de nuevo.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _calcularRuta() async {
    if (_origenCoords == null || _destinoCoords == null) return;
    if (_calculando) return; // evitar cálculos concurrentes

    final storage = context.read<StorageService>();
    final city = storage.ciudadSeleccionada;

    setState(() {
      _calculando = true;
      _error = null;
      _ruta = null; // limpiar ruta anterior para que la card desaparezca mientras carga
    });

    try {
      final apiService = ApiService(const FlutterSecureStorage());
      final resultado = await apiService.calcularRuta(
        city: city,
        origin: [_origenCoords!.longitude, _origenCoords!.latitude],
        destination: [_destinoCoords!.longitude, _destinoCoords!.latitude],
        perfil: _perfil,
      );
      setState(() => _ruta = resultado);

      // Reubicar el mapa usando TODOS los puntos de la ruta (no solo origen→destino)
      // para que el trayecto completo quede visible aunque sea curvo
      final puntos = resultado['puntos'] as List<dynamic>?;
      if (puntos != null && puntos.isNotEmpty) {
        final latLngs = puntos
            .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
            .toList();
        final bounds = LatLngBounds.fromPoints(latLngs);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
        );
      }
    } catch (e) {
      String mensaje;
      if (e is DioException) {
        switch (e.type) {
          case DioExceptionType.connectionError:
            mensaje = 'No se pudo conectar al servidor. Verifica que el backend esté corriendo en localhost:8000.';
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.receiveTimeout:
            mensaje = 'El servidor tardó demasiado en responder. Intenta de nuevo.';
          case DioExceptionType.badResponse:
            final detail = e.response?.data is Map ? (e.response!.data as Map)['detail'] : null;
            mensaje = detail?.toString() ?? 'Error al calcular la ruta (código ${e.response?.statusCode}).';
          default:
            mensaje = 'Error de red al calcular la ruta. Intenta de nuevo.';
        }
      } else {
        mensaje = 'Error inesperado al calcular la ruta.';
      }
      setState(() => _error = mensaje);
    } finally {
      setState(() => _calculando = false);
    }
  }

  void _limpiarRuta() {
    _detenerNavegacion();
    setState(() {
      _ruta = null;
      _origenCoords = null;
      _destinoCoords = null;
      _origenNombre = null;
      _destinoNombre = null;
      _origenCtrl.clear();
      _destinoCtrl.clear();
      _error = null;
    });
  }

  void _iniciarNavegacion() {
    _positionSub = _locationService.streamUbicacion.listen((pos) {
      if (mounted) {
        setState(() {
          _posicionActual = LatLng(pos.latitude, pos.longitude);
          _heading = pos.heading;
          _speed = pos.speed;
        });
        _mapController.move(_posicionActual!, _mapController.camera.zoom);
      }
    });
    setState(() => _navegando = true);
  }

  void _detenerNavegacion() {
    _positionSub?.cancel();
    _positionSub = null;
    setState(() {
      _navegando = false;
      _posicionActual = null;
      _heading = null;
      _speed = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final listo = _origenCoords != null && _destinoCoords != null;

    // CartoDB Dark Matter: gratuito, sin API key, carga correctamente en oscuro
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      body: Column(
        children: [
          // Mapa superior
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _origenCoords ?? const LatLng(4.6097, -74.0817),
                    initialZoom: 13,
                    minZoom: 5,
                    maxZoom: 19,
                    // Habilitar explícitamente zoom, pan y rotación
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: tileUrl,
                      subdomains: isDark
                          ? const ['a', 'b', 'c', 'd']   // CartoDB usa 4 subdominios
                          : const ['a', 'b', 'c'],
                      userAgentPackageName: 'co.rutalibre.app',
                    ),
                    // Marcadores de preview (antes de calcular)
                    if (_ruta == null)
                      MarkerLayer(
                        markers: [
                          if (_origenCoords != null)
                            Marker(
                              point: _origenCoords!,
                              // Ciclista cuando es la ubicación actual, círculo verde cuando es búsqueda
                              width: _origenNombre == 'Mi ubicación actual' ? 44 : 28,
                              height: _origenNombre == 'Mi ubicación actual' ? 44 : 28,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                                ),
                                child: _origenNombre == 'Mi ubicación actual'
                                    ? const Center(child: Text('🚴', style: TextStyle(fontSize: 22)))
                                    : null,
                              ),
                            ),
                          if (_destinoCoords != null)
                            Marker(
                              point: _destinoCoords!,
                              width: 28,
                              height: 28,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                                ),
                              ),
                            ),
                        ],
                      ),
                    // Ruta calculada
                    if (_ruta != null) RouteDisplayWidget(rutaData: _ruta!),
                    // Posición en navegación
                    if (_navegando && _posicionActual != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _posicionActual!,
                            width: 32,
                            height: 32,
                            child: Transform.rotate(
                              angle: (_heading ?? 0) * 3.14159 / 180,
                              child: const Icon(Icons.navigation, color: Color(0xFF16A34A), size: 32),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Velocidad actual en navegación
                if (_navegando)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _speed != null ? (_speed! * 3.6).toStringAsFixed(1) : '0.0',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: 4),
                            Text('km/h', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Panel inferior con formulario / resumen
          Expanded(
            flex: 3,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: SingleChildScrollView(
                primary: true,
                physics: const BouncingScrollPhysics(),
                // Padding inferior extra para que el botón "Nueva ruta" no quede
                // oculto detrás del bottom navigation bar ni del safe area
                padding: EdgeInsets.fromLTRB(
                  16, 16, 16,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Título
                    Row(
                      children: [
                        Icon(Icons.navigation, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Calcular ruta', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Campo origen
                    _buildCampoBusqueda(
                      controller: _origenCtrl,
                      label: 'Origen',
                      placeholder: 'Ej: Parque de la 93, Chapinero…',
                      color: const Color(0xFF16A34A),
                      icon: Icons.location_on,
                      sugerencias: _sugerenciasOrigen,
                      buscando: _buscandoOrigen,
                      sinResultados: _sinResultadosOrigen,
                      onChanged: _buscarOrigen,
                      onSeleccion: _seleccionarOrigen,
                      onUsarUbicacion: _usarUbicacionOrigen,
                    ),

                    // Flecha visual
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Center(child: Icon(Icons.arrow_downward, size: 20, color: Color(0xFF94A3B8))),
                    ),

                    // Campo destino
                    _buildCampoBusqueda(
                      controller: _destinoCtrl,
                      label: 'Destino',
                      placeholder: 'Ej: Universidad Nacional, Teusaquillo…',
                      color: const Color(0xFFDC2626),
                      icon: Icons.flag,
                      sugerencias: _sugerenciasDestino,
                      buscando: _buscandoDestino,
                      sinResultados: _sinResultadosDestino,
                      onChanged: _buscarDestino,
                      onSeleccion: _seleccionarDestino,
                    ),
                    const SizedBox(height: 12),

                    // Perfil de ruta — Row en lugar de ListView para evitar
                    // conflictos de gestos (tap vs. scroll horizontal)
                    Text(
                      'Tipo de ruta',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _perfiles.map((p) {
                        final sel = _perfil == p['value'];
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: p['value'] == _perfiles.last['value'] ? 0 : 8,
                            ),
                            // Material + InkWell garantizan detección de tap
                            // aunque el fondo sea transparente (HitTestBehavior.opaque implícito)
                            child: Material(
                              color: sel ? theme.colorScheme.primaryContainer : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: _calculando
                                    ? null
                                    : () {
                                        if (_perfil == p['value']) {
                                          // Mismo perfil: recalcula si ya hay ruta cargada
                                          if (_ruta != null && _origenCoords != null && _destinoCoords != null) {
                                            _calcularRuta();
                                          }
                                          return;
                                        }
                                        // Cambiar perfil y limpiar ruta anterior para que desaparezca inmediatamente
                                        // mientras se calcula la nueva ruta
                                        setState(() {
                                          _perfil = p['value']!;
                                          _ruta = null; // Limpiar ruta anterior
                                        });
                                        if (_origenCoords != null && _destinoCoords != null) {
                                          _calcularRuta();
                                        }
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: sel ? theme.colorScheme.primary : theme.colorScheme.outline,
                                      width: sel ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${p['emoji']} ${p['label']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: sel
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        p['desc']!,
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Botón calcular — solo visible cuando aún no hay ruta calculada
                    // o mientras está calculando. Una vez calculada, los chips
                    // recalculan al tocarse, así que el botón ya no es necesario.
                    if (_ruta == null)
                      ElevatedButton.icon(
                        onPressed: _calculando || !listo ? null : _calcularRuta,
                        icon: _calculando
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.route),
                        label: Text(_calculando ? 'Calculando…' : '🗺️ Calcular ruta'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                        ),
                      ),

                    // Error
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('⚠️ $_error', style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                        ),
                      ),

                    // Resumen de ruta
                    if (_ruta != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.primary),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('✅ Ruta lista', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _perfiles.firstWhere((p) => p['value'] == _perfil, orElse: () => _perfiles[0])['label']!,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _statItem('Distancia', '${_ruta!['distancia_km']} km')),
                                Expanded(child: _statItem('Tiempo', '${_ruta!['tiempo_minutos']} min')),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(child: _statItem('Subida', '↑ ${(_ruta!['elevacion_ganada_m'] as num).round()} m')),
                                Expanded(child: _statItem('Bajada', '↓ ${(_ruta!['elevacion_perdida_m'] as num).round()} m')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Botón navegación
                      ElevatedButton.icon(
                        onPressed: _navegando ? _detenerNavegacion : _iniciarNavegacion,
                        icon: Icon(_navegando ? Icons.stop : Icons.play_arrow),
                        label: Text(_navegando ? 'Detener seguimiento' : 'Iniciar navegación'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navegando ? theme.colorScheme.error : theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Botón nueva ruta
                      OutlinedButton.icon(
                        onPressed: _limpiarRuta,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Nueva ruta'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Widget _buildCampoBusqueda({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required Color color,
    required IconData icon,
    required List<ResultadoBusqueda> sugerencias,
    required bool buscando,
    required bool sinResultados,
    required void Function(String) onChanged,
    required void Function(ResultadoBusqueda) onSeleccion,
    VoidCallback? onUsarUbicacion,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: theme.colorScheme.onSurface)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            if (onUsarUbicacion != null) ...[
              const SizedBox(width: 6),
              IconButton(
                onPressed: onUsarUbicacion,
                icon: Icon(Icons.my_location, size: 20, color: color),
                tooltip: 'Usar mi ubicación',
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ],
        ),
        // Indicadores de búsqueda
        if (buscando)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Buscando…', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ),
        if (!buscando && sinResultados)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Sin resultados — prueba con el barrio o una referencia cercana',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ),
        // Lista de sugerencias
        if (sugerencias.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: sugerencias.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: theme.colorScheme.outline),
              itemBuilder: (context, i) {
                final r = sugerencias[i];
                return InkWell(
                  onTap: () => onSeleccion(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Text('📍', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              if (r.detalle.isNotEmpty)
                                Text(r.detalle, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
