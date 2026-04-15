// apps/mobile/lib/features/map/screens/map_screen.dart
// Pantalla principal del mapa con banner de ciudad, selector y ubicación

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../widgets/route_display_widget.dart';

/// Pantalla principal del mapa ciclista con banner de ciudad.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _centroBogota = LatLng(4.6097, -74.0817);

  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();

  LatLng? _ubicacionActual;
  bool _cargandoUbicacion = false;
  Map<String, dynamic>? _rutaActual;

  // Configuración de la ciudad
  Map<String, dynamic>? _cityConfig;
  List<dynamic> _ciudadesDisponibles = [];

  @override
  void initState() {
    super.initState();
    _cargarCiudad();
    _obtenerUbicacionAutomatica();
  }

  Future<void> _cargarCiudad() async {
    final storage = context.read<StorageService>();
    final city = storage.ciudadSeleccionada;

    try {
      final apiService = ApiService(const FlutterSecureStorage());
      final config = await apiService.obtenerCiudad(city);
      final ciudades = await apiService.listarCiudades();
      if (mounted) {
        setState(() {
          _cityConfig = config;
          _ciudadesDisponibles = ciudades;
        });
      }
    } catch (_) {
      // No bloquear la UI si la API no responde
    }
  }

  Future<void> _obtenerUbicacionAutomatica() async {
    try {
      final posicion = await _locationService.obtenerUbicacionActual();
      if (mounted) {
        final latLng = LatLng(posicion.latitude, posicion.longitude);
        setState(() => _ubicacionActual = latLng);
        // Mover el mapa a la ubicación del usuario al cargar
        _mapController.move(latLng, 15);
      }
    } catch (_) {
      // Sin permisos o GPS desactivado — el mapa queda centrado en Bogotá
    }
  }

  Future<void> _irAUbicacionActual() async {
    if (_cargandoUbicacion) return;
    setState(() => _cargandoUbicacion = true);

    try {
      final posicion = await _locationService.obtenerUbicacionActual();
      if (!mounted) return;
      final latLng = LatLng(posicion.latitude, posicion.longitude);
      setState(() => _ubicacionActual = latLng);
      _mapController.move(latLng, 16);
    } on LocationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 ${e.mensaje}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 No se pudo obtener tu ubicación. Activa el GPS e intenta de nuevo.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _cargandoUbicacion = false);
    }
  }

  void _mostrarSelectorCiudad() {
    final storage = context.read<StorageService>();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Seleccionar ciudad', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1),
            ..._ciudadesDisponibles.map((c) {
              final ciudad = c as Map<String, dynamic>;
              final slug = ciudad['slug'] as String? ?? '';
              final nombre = ciudad['name'] as String? ?? slug;
              final status = ciudad['status'] as String? ?? '';
              final esActual = slug == storage.ciudadSeleccionada;

              return ListTile(
                leading: Icon(
                  esActual ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: esActual ? theme.colorScheme.primary : null,
                ),
                title: Text(nombre, style: TextStyle(fontWeight: esActual ? FontWeight.w600 : FontWeight.normal)),
                subtitle: status == 'active' ? null : Text(status, style: const TextStyle(fontSize: 12)),
                enabled: status == 'active',
                onTap: () {
                  storage.setCiudad(slug);
                  Navigator.pop(context);
                  _cargarCiudad();
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final theme = Theme.of(context);
    final storage = context.read<StorageService>();

    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_bike, size: 20),
            const SizedBox(width: 6),
            const Text('RutaLibre', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          // Selector de ciudad
          if (_ciudadesDisponibles.isNotEmpty)
            TextButton.icon(
              onPressed: _mostrarSelectorCiudad,
              icon: Icon(Icons.location_city, size: 16,
                  color: isDark ? Colors.white : Colors.black87),
              label: Text(
                storage.ciudadSeleccionada.substring(0, 1).toUpperCase() +
                    storage.ciudadSeleccionada.substring(1),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          // Toggle tema
          IconButton(
            onPressed: () => themeProvider.toggleTheme(),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? Colors.white : Colors.black87,
            ),
            tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner info de la ciudad
          if (_cityConfig != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primaryContainer,
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    '📍 ${_cityConfig!['name'] ?? ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '🏔️ ${_cityConfig!['elevation_avg_m'] ?? 0} m s.n.m.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  if (_cityConfig!['ciclovia_schedule'] == 'sundays_and_holidays')
                    Text(
                      '🚦 Ciclovía dom. y festivos',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                ],
              ),
            ),

          // Mapa principal
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _centroBogota,
                    initialZoom: 13,
                    minZoom: 5,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: tileUrl,
                      subdomains: isDark
                          ? const ['a', 'b', 'c', 'd']
                          : const ['a', 'b', 'c'],
                      userAgentPackageName: 'co.rutalibre.app',
                    ),

                    // Marcador de ubicación actual — icono ciclista
                    if (_ubicacionActual != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _ubicacionActual!,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
                              ),
                              child: const Center(
                                child: Text('🚴', style: TextStyle(fontSize: 22)),
                              ),
                            ),
                          ),
                        ],
                      ),

                    // Ruta calculada
                    if (_rutaActual != null) RouteDisplayWidget(rutaData: _rutaActual!),
                  ],
                ),

                // Botón de ubicación actual
                Positioned(
                  bottom: 24,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'ubicacion',
                    mini: true,
                    onPressed: _irAUbicacionActual,
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.primary,
                    child: _cargandoUbicacion
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
