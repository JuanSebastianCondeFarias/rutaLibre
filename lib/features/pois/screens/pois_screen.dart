// apps/mobile/lib/features/pois/screens/pois_screen.dart
// Pantalla de POIs: mapa + lista, filtros, geolocalización por radio y reporte

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/theme_provider.dart';

/// Pantalla de puntos de interés ciclistas con mapa, lista y reporte.
class PoisScreen extends StatefulWidget {
  const PoisScreen({super.key});

  @override
  State<PoisScreen> createState() => _PoisScreenState();
}

class _PoisScreenState extends State<PoisScreen> {
  static const _tipos = [
    {'value': '', 'label': 'Todos', 'emoji': '🗺️'},
    {'value': 'repair_shop', 'label': 'Talleres', 'emoji': '🔧'},
    {'value': 'bike_store', 'label': 'Tiendas', 'emoji': '🚲'},
    {'value': 'parking', 'label': 'Parqueadero', 'emoji': '🅿️'},
    {'value': 'water_point', 'label': 'Agua', 'emoji': '💧'},
    {'value': 'rest_area', 'label': 'Descanso', 'emoji': '🌳'},
    {'value': 'bike_sharing', 'label': 'Tembici', 'emoji': '🔄'},
  ];

  static const _radios = [
    {'value': 0.5, 'label': '500 m'},
    {'value': 1.0, 'label': '1 km'},
    {'value': 2.0, 'label': '2 km'},
    {'value': 5.0, 'label': '5 km'},
  ];

  static const _emojis = {
    'repair_shop': '🔧',
    'bike_store': '🚲',
    'parking': '🅿️',
    'water_point': '💧',
    'rest_area': '🌳',
    'bike_sharing': '🔄',
  };

  String _tipoFiltro = '';
  List<dynamic> _pois = [];
  bool _cargando = true;
  String? _error;
  bool _vistaLista = false;

  // Geolocalización
  LatLng? _ubicacion;
  double _radioKm = 2.0;
  bool _buscandoUbicacion = false;

  // Modo reporte POI
  bool _modoReporte = false;
  LatLng? _reporteCoord;
  bool _mostrarModalReporte = false;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _cargarPois();
  }

  Future<void> _cargarPois() async {
    final storage = context.read<StorageService>();
    final city = storage.ciudadSeleccionada;

    setState(() => _cargando = true);

    try {
      final apiService = ApiService(const FlutterSecureStorage());
      final pois = await apiService.listarPoisConUbicacion(
        city,
        tipo: _tipoFiltro.isEmpty ? null : _tipoFiltro,
        lat: _ubicacion?.latitude,
        lng: _ubicacion?.longitude,
        radioKm: _ubicacion != null ? _radioKm : null,
      );
      if (mounted) {
        setState(() {
          _pois = pois;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error cargando POIs: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _obtenerUbicacion() async {
    setState(() => _buscandoUbicacion = true);
    try {
      final pos = await LocationService().obtenerUbicacionActual();
      setState(() => _ubicacion = LatLng(pos.latitude, pos.longitude));
      _cargarPois();
    } on LocationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  void _quitarUbicacion() {
    setState(() => _ubicacion = null);
    _cargarPois();
  }

  void _handleMapTap(LatLng point) {
    if (!_modoReporte) return;
    setState(() {
      _reporteCoord = point;
      _modoReporte = false;
      _mostrarModalReporte = true;
    });
  }

  void _cancelarReporte() {
    setState(() {
      _modoReporte = false;
      _reporteCoord = null;
      _mostrarModalReporte = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.build_outlined, size: 22),
            const SizedBox(width: 8),
            Text('POIs (${_cargando ? '…' : _pois.length})'),
          ],
        ),
        actions: [
          // Toggle vista
          IconButton(
            onPressed: () => setState(() => _vistaLista = !_vistaLista),
            icon: Icon(_vistaLista ? Icons.map : Icons.list),
            tooltip: _vistaLista ? 'Ver mapa' : 'Ver lista',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de herramientas
          _buildToolbar(theme),

          // Filtros por tipo
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _tipos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final tipo = _tipos[i];
                final sel = _tipoFiltro == tipo['value'];
                return FilterChip(
                  label: Text('${tipo['emoji']} ${tipo['label']}', style: const TextStyle(fontSize: 11)),
                  selected: sel,
                  onSelected: (_) {
                    setState(() => _tipoFiltro = tipo['value']!);
                    _cargarPois();
                  },
                  selectedColor: theme.colorScheme.primaryContainer,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Info de proximidad
          if (_ubicacion != null && !_cargando)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.near_me, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Mostrando ${_pois.length} POIs a menos de ${_radioKm >= 1 ? '${_radioKm.toInt()} km' : '${(_radioKm * 1000).toInt()} m'}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),

          // Contenido principal
          Expanded(
            child: _vistaLista ? _buildListView(theme) : _buildMapView(theme, tileUrl),
          ),

          // Modal de reporte POI
          if (_mostrarModalReporte && _reporteCoord != null)
            _ModalReportarPOI(
              coord: _reporteCoord!,
              onClose: _cancelarReporte,
              onExito: () {
                _cancelarReporte();
                _cargarPois();
              },
            ),
        ],
      ),
      // FAB para reportar POI (solo en vista mapa)
      floatingActionButton: !_vistaLista && !_modoReporte
          ? FloatingActionButton.extended(
              onPressed: () => setState(() {
                _modoReporte = true;
                _reporteCoord = null;
              }),
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Reportar POI'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Botón mi ubicación
          _buildLocationButton(theme),
          const SizedBox(width: 8),

          // Selector de radio (solo si hay ubicación)
          if (_ubicacion != null) _buildRadioSelector(theme),
        ],
      ),
    );
  }

  Widget _buildLocationButton(ThemeData theme) {
    final activa = _ubicacion != null;
    return OutlinedButton.icon(
      onPressed: _buscandoUbicacion ? null : (activa ? _quitarUbicacion : _obtenerUbicacion),
      icon: Icon(
        activa ? Icons.location_off : Icons.my_location,
        size: 16,
        color: activa ? theme.colorScheme.primary : null,
      ),
      label: Text(
        _buscandoUbicacion ? 'Buscando...' : (activa ? 'Mi ubicación activa' : 'Mi ubicación'),
        style: const TextStyle(fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: activa ? BorderSide(color: theme.colorScheme.primary) : null,
      ),
    );
  }

  Widget _buildRadioSelector(ThemeData theme) {
    return Row(
      children: [
        Text('Radio:', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        const SizedBox(width: 4),
        ..._radios.map((r) {
          final v = r['value'] as double;
          final sel = _radioKm == v;
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: () {
                setState(() => _radioKm = v);
                _cargarPois();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? theme.colorScheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: sel ? Border.all(color: theme.colorScheme.primary, width: 1) : null,
                ),
                child: Text(
                  r['label'] as String,
                  style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMapView(ThemeData theme, String tileUrl) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _ubicacion ?? const LatLng(4.6097, -74.0817),
            initialZoom: _ubicacion != null ? 14 : 12,
            onTap: (_, point) => _handleMapTap(point),
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: isDark
                  ? const ['a', 'b', 'c', 'd']
                  : const ['a', 'b', 'c'],
              userAgentPackageName: 'co.rutalibre.app',
            ),
            // Marcadores de POIs
            MarkerLayer(
              markers: _pois.map<Marker>((poi) {
                final p = poi as Map<String, dynamic>;
                final lat = (p['lat'] as num?)?.toDouble() ?? 0;
                final lng = (p['lng'] as num?)?.toDouble() ?? 0;
                final tipo = p['tipo'] as String? ?? '';
                final emoji = _emojis[tipo] ?? '📍';
                final nombre = p['nombre'] as String? ?? '';

                return Marker(
                  point: LatLng(lat, lng),
                  width: 36,
                  height: 36,
                  child: GestureDetector(
                    onTap: () => _mostrarDetallePoi(context, p),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.primary, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
                    ),
                  ),
                );
              }).toList(),
            ),
            // Ubicación del usuario
            if (_ubicacion != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _ubicacion!,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),

        // Banner modo reporte
        if (_modoReporte)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📍 Toca el mapa donde está el POI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _cancelarReporte,
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),

        // Indicador de carga
        if (_cargando)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildListView(ThemeData theme) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _cargarPois, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (_pois.isEmpty) {
      return Center(
        child: Text(
          _ubicacion != null
              ? 'No hay POIs de este tipo a menos de ${_radioKm >= 1 ? '${_radioKm.toInt()} km' : '${(_radioKm * 1000).toInt()} m'}'
              : 'No hay POIs de este tipo',
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarPois,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pois.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _PoiCard(poi: _pois[i] as Map<String, dynamic>),
      ),
    );
  }

  void _mostrarDetallePoi(BuildContext context, Map<String, dynamic> poi) {
    final theme = Theme.of(context);
    final tipo = poi['tipo'] as String? ?? '';
    final emoji = _emojis[tipo] ?? '📍';

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(poi['nombre'] as String? ?? '', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      if (poi['direccion'] != null)
                        Text(poi['direccion'] as String, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ],
            ),
            if (poi['descripcion'] != null) ...[
              const SizedBox(height: 12),
              Text(poi['descripcion'] as String),
            ],
            if (poi['horario'] != null) ...[
              const SizedBox(height: 8),
              Text('🕐 ${poi['horario']}', style: const TextStyle(fontSize: 13)),
            ],
            if (poi['telefono'] != null) ...[
              const SizedBox(height: 4),
              Text('📞 ${poi['telefono']}', style: const TextStyle(fontSize: 13)),
            ],
            if (poi['rating_promedio'] != null) ...[
              const SizedBox(height: 8),
              Text('⭐ ${(poi['rating_promedio'] as num).toStringAsFixed(1)}/5', style: TextStyle(color: theme.colorScheme.secondary)),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de POI para vista lista.
class _PoiCard extends StatelessWidget {
  final Map<String, dynamic> poi;
  const _PoiCard({required this.poi});

  static const _emojis = {
    'repair_shop': '🔧',
    'bike_store': '🚲',
    'parking': '🅿️',
    'water_point': '💧',
    'rest_area': '🌳',
    'bike_sharing': '🔄',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tipo = poi['tipo'] as String? ?? '';
    final emoji = _emojis[tipo] ?? '📍';
    final rating = poi['rating_promedio'];

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Text(emoji, style: const TextStyle(fontSize: 28)),
        title: Text(poi['nombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poi['direccion'] != null)
              Text(poi['direccion'] as String, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            if (poi['horario'] != null)
              Text('🕐 ${poi['horario']}', style: const TextStyle(fontSize: 12)),
            if (poi['telefono'] != null)
              Text('📞 ${poi['telefono']}', style: const TextStyle(fontSize: 12)),
            if (rating != null)
              Text('⭐ ${(rating as num).toStringAsFixed(1)}/5', style: const TextStyle(fontSize: 12)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

/// Modal para reportar un nuevo POI.
class _ModalReportarPOI extends StatefulWidget {
  final LatLng coord;
  final VoidCallback onClose;
  final VoidCallback onExito;

  const _ModalReportarPOI({required this.coord, required this.onClose, required this.onExito});

  @override
  State<_ModalReportarPOI> createState() => _ModalReportarPOIState();
}

class _ModalReportarPOIState extends State<_ModalReportarPOI> {
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _horarioCtrl = TextEditingController();
  String _tipoPoi = 'repair_shop';
  bool _enviando = false;
  bool _exito = false;

  static const _tiposPoi = [
    {'value': 'repair_shop', 'label': 'Taller', 'emoji': '🔧'},
    {'value': 'bike_store', 'label': 'Tienda', 'emoji': '🚲'},
    {'value': 'parking', 'label': 'Parqueadero', 'emoji': '🅿️'},
    {'value': 'water_point', 'label': 'Agua', 'emoji': '💧'},
    {'value': 'rest_area', 'label': 'Descanso', 'emoji': '🌳'},
    {'value': 'bike_sharing', 'label': 'Bici compartida', 'emoji': '🔄'},
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _telefonoCtrl.dispose();
    _horarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es requerido')),
      );
      return;
    }

    final storage = context.read<StorageService>();
    setState(() => _enviando = true);

    try {
      final apiService = ApiService(const FlutterSecureStorage());
      final descripcion = [
        'Tipo POI: $_tipoPoi',
        'Nombre: ${_nombreCtrl.text}',
        if (_descripcionCtrl.text.isNotEmpty) _descripcionCtrl.text,
        if (_telefonoCtrl.text.isNotEmpty) 'Tel: ${_telefonoCtrl.text}',
        if (_horarioCtrl.text.isNotEmpty) 'Horario: ${_horarioCtrl.text}',
      ].join('\n');

      await apiService.crearContribucion(
        city: storage.ciudadSeleccionada,
        tipo: 'poi_add',
        descripcion: descripcion,
        lat: widget.coord.latitude,
        lng: widget.coord.longitude,
      );
      setState(() => _exito = true);
      Future.delayed(const Duration(milliseconds: 1800), widget.onExito);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar el reporte')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _exito
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 48),
                    const SizedBox(height: 12),
                    const Text('¡POI reportado!', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('La comunidad votará para aprobarlo.', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Reportar POI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          GestureDetector(onTap: widget.onClose, child: const Icon(Icons.close, size: 20)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tipo POI
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _tiposPoi.map((t) {
                          final sel = _tipoPoi == t['value'];
                          return FilterChip(
                            label: Text('${t['emoji']} ${t['label']}', style: const TextStyle(fontSize: 11)),
                            selected: sel,
                            onSelected: (_) => setState(() => _tipoPoi = t['value']!),
                            selectedColor: theme.colorScheme.primaryContainer,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del POI *', isDense: true)),
                      const SizedBox(height: 8),
                      TextField(controller: _descripcionCtrl, decoration: const InputDecoration(labelText: 'Descripción', isDense: true), maxLines: 2),
                      const SizedBox(height: 8),
                      TextField(controller: _telefonoCtrl, decoration: const InputDecoration(labelText: 'Teléfono', isDense: true), keyboardType: TextInputType.phone),
                      const SizedBox(height: 8),
                      TextField(controller: _horarioCtrl, decoration: const InputDecoration(labelText: 'Horario', isDense: true)),
                      const SizedBox(height: 8),

                      Text(
                        '📍 ${widget.coord.latitude.toStringAsFixed(5)}, ${widget.coord.longitude.toStringAsFixed(5)}',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 16),

                      ElevatedButton(
                        onPressed: _enviando ? null : _enviar,
                        child: Text(_enviando ? 'Enviando...' : 'Reportar POI'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
