// apps/mobile/lib/features/tracking/screens/tracking_screen.dart
// Pantalla de grabación de actividad ciclista en tiempo real

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/services/tracking_service.dart';
import '../../../core/theme/theme_provider.dart';

/// Pantalla principal de tracking con mapa en tiempo real.
///
/// Muestra el recorrido como Polyline sobre OSM, un panel de stats inferior
/// y botones de control de grabación según el estado actual.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _mapController = MapController();
  bool _siguiendoUbicacion = true;

  // Colores del tema definidos en CLAUDE.md
  static const _colorGrabando = Color(0xFF16A34A); // verde primario
  static const _colorPausado = Color(0xFFF97316); // naranja secundario
  static const _colorDetener = Color(0xFFEF4444); // rojo error

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final theme = Theme.of(context);

    // Tiles según tema
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    // Mover mapa automáticamente al último punto si se está grabando
    if (_siguiendoUbicacion &&
        tracking.estaGrabando &&
        tracking.puntos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(tracking.puntos.last, _mapController.camera.zoom);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador visual del estado actual
            _IndicadorEstado(estado: tracking.estado),
            const SizedBox(width: 8),
            Text(
              _tituloSegunEstado(tracking.estado),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── Mapa principal ────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(4.6097, -74.0817),
                    initialZoom: 16,
                    minZoom: 5,
                    maxZoom: 19,
                    onMapEvent: (_) {
                      // Al interactuar con el mapa, dejar de seguir la ubicación
                      if (_siguiendoUbicacion) {
                        setState(() => _siguiendoUbicacion = false);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: tileUrl,
                      subdomains: isDark
                          ? const ['a', 'b', 'c', 'd']
                          : const ['a', 'b', 'c'],
                      userAgentPackageName: 'co.rutalibre.app',
                    ),

                    // Polyline del recorrido grabado
                    if (tracking.puntos.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: tracking.puntos.toList(),
                            strokeWidth: 5.0,
                            color: tracking.estaPausado
                                ? _colorPausado
                                : _colorGrabando,
                          ),
                        ],
                      ),

                    // Marcador en la posición actual (último punto)
                    if (tracking.puntos.isNotEmpty)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: tracking.puntos.last,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: tracking.estaPausado
                                    ? _colorPausado
                                    : _colorGrabando,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text('🚴',
                                    style: TextStyle(fontSize: 20)),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Botón flotante "Mi ubicación"
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'tracking_ubicacion',
                    mini: true,
                    onPressed: _centrarEnUbicacion,
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: _siguiendoUbicacion
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    tooltip: 'Centrar en mi ubicación',
                    child: Icon(
                      _siguiendoUbicacion
                          ? Icons.my_location
                          : Icons.location_searching,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Panel inferior de estadísticas ───────────────────
          _PanelStats(tracking: tracking),

          // ─── Botones de control ────────────────────────────────
          _PanelControles(
            tracking: tracking,
            onIniciar: _iniciarGrabacion,
            onPausar: () => tracking.pausar(),
            onReanudar: () => tracking.reanudar(),
            onDetener: () => _confirmarDetener(context, tracking),
            colorGrabando: _colorGrabando,
            colorPausado: _colorPausado,
            colorDetener: _colorDetener,
          ),
        ],
      ),
    );
  }

  // ─── Acciones ──────────────────────────────────────────────────

  Future<void> _iniciarGrabacion() async {
    final tracking = context.read<TrackingService>();
    await tracking.iniciarGrabacion();

    // Activar seguimiento automático al iniciar
    setState(() => _siguiendoUbicacion = true);
  }

  void _centrarEnUbicacion() {
    final tracking = context.read<TrackingService>();
    if (tracking.puntos.isNotEmpty) {
      _mapController.move(tracking.puntos.last, 16);
      setState(() => _siguiendoUbicacion = true);
    }
  }

  Future<void> _confirmarDetener(
    BuildContext context,
    TrackingService tracking,
  ) async {
    // Diálogo de confirmación antes de detener
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Detener grabación?'),
        content: const Text(
          'Se guardará la actividad con el recorrido y las estadísticas actuales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Detener'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    // Modal para nombrar la actividad
    await _mostrarModalGuardar(context, tracking);
  }

  Future<void> _mostrarModalGuardar(
    BuildContext context,
    TrackingService tracking,
  ) async {
    final controladorNombre = TextEditingController(
      text: _sugerirNombreActividad(),
    );
    final storage = context.read<StorageService>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _ModalGuardarActividad(
          controlador: controladorNombre,
          distanciaKm: tracking.distanciaTotalKm,
          tiempoTranscurrido: tracking.tiempoTranscurrido,
          onGuardar: () async {
            Navigator.pop(ctx);
            await tracking.detener(
              title: controladorNombre.text,
              citySlug: storage.ciudadSeleccionada,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Actividad guardada correctamente'),
                  backgroundColor: Color(0xFF16A34A),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  String _sugerirNombreActividad() {
    final ahora = DateTime.now();
    final hora = ahora.hour;
    if (hora < 12) return 'Rodada matutina';
    if (hora < 17) return 'Rodada de la tarde';
    return 'Rodada nocturna';
  }

  String _tituloSegunEstado(TrackingEstado estado) {
    switch (estado) {
      case TrackingEstado.idle:
        return 'Grabar actividad';
      case TrackingEstado.recording:
        return 'Grabando...';
      case TrackingEstado.paused:
        return 'Pausado';
    }
  }
}

// ─── Widgets internos ──────────────────────────────────────────

/// Indicador visual del estado de grabación (punto animado).
class _IndicadorEstado extends StatelessWidget {
  final TrackingEstado estado;

  const _IndicadorEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (estado) {
      case TrackingEstado.idle:
        color = Colors.grey;
        break;
      case TrackingEstado.recording:
        color = const Color(0xFF16A34A);
        break;
      case TrackingEstado.paused:
        color = const Color(0xFFF97316);
        break;
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: estado == TrackingEstado.recording
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 2)]
            : null,
      ),
    );
  }
}

/// Panel con estadísticas en tiempo real: tiempo, distancia, velocidades.
class _PanelStats extends StatelessWidget {
  final TrackingService tracking;

  const _PanelStats({required this.tracking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.timer_outlined,
            valor: _formatearTiempo(tracking.tiempoTranscurrido),
            etiqueta: 'Tiempo',
          ),
          _Divisor(),
          _StatItem(
            icon: Icons.straighten,
            valor: '${tracking.distanciaTotalKm.toStringAsFixed(2)} km',
            etiqueta: 'Distancia',
          ),
          _Divisor(),
          _StatItem(
            icon: Icons.speed,
            valor: '${tracking.velocidadActualKmh.toStringAsFixed(1)} km/h',
            etiqueta: 'Velocidad',
          ),
          _Divisor(),
          _StatItem(
            icon: Icons.trending_up,
            valor: '${tracking.velocidadPromedioKmh.toStringAsFixed(1)} km/h',
            etiqueta: 'Promedio',
          ),
        ],
      ),
    );
  }

  String _formatearTiempo(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String valor;
  final String etiqueta;

  const _StatItem({
    required this.icon,
    required this.valor,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          valor,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        Text(
          etiqueta,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _Divisor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Theme.of(context).colorScheme.outline,
    );
  }
}

/// Panel de botones de control adaptados al estado actual.
class _PanelControles extends StatelessWidget {
  final TrackingService tracking;
  final VoidCallback onIniciar;
  final VoidCallback onPausar;
  final VoidCallback onReanudar;
  final VoidCallback onDetener;
  final Color colorGrabando;
  final Color colorPausado;
  final Color colorDetener;

  const _PanelControles({
    required this.tracking,
    required this.onIniciar,
    required this.onPausar,
    required this.onReanudar,
    required this.onDetener,
    required this.colorGrabando,
    required this.colorPausado,
    required this.colorDetener,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: _buildBotones(),
      ),
    );
  }

  Widget _buildBotones() {
    switch (tracking.estado) {
      case TrackingEstado.idle:
        // Estado inicial: solo botón de iniciar
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onIniciar,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Iniciar grabación',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorGrabando,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        );

      case TrackingEstado.recording:
        // Grabando: pausar (naranja) + detener (rojo)
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onPausar,
                  icon: const Icon(Icons.pause_rounded),
                  label: const Text('Pausar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorPausado,
                    side: BorderSide(color: colorPausado, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 52,
              width: 52,
              child: ElevatedButton(
                onPressed: onDetener,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorDetener,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Icon(Icons.stop_rounded, size: 28),
              ),
            ),
          ],
        );

      case TrackingEstado.paused:
        // Pausado: reanudar (verde) + detener (rojo)
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onReanudar,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Reanudar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorGrabando,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 52,
              width: 52,
              child: ElevatedButton(
                onPressed: onDetener,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorDetener,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Icon(Icons.stop_rounded, size: 28),
              ),
            ),
          ],
        );
    }
  }
}

/// Modal bottom sheet para nombrar y guardar la actividad al finalizar.
class _ModalGuardarActividad extends StatelessWidget {
  final TextEditingController controlador;
  final double distanciaKm;
  final Duration tiempoTranscurrido;
  final VoidCallback onGuardar;

  const _ModalGuardarActividad({
    required this.controlador,
    required this.distanciaKm,
    required this.tiempoTranscurrido,
    required this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Color(0xFF16A34A), size: 28),
              const SizedBox(width: 8),
              Text(
                'Guardar actividad',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Resumen de stats
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ResumenStat(
                  valor: '${distanciaKm.toStringAsFixed(2)} km',
                  etiqueta: 'Distancia',
                ),
                _ResumenStat(
                  valor: _formatearTiempo(tiempoTranscurrido),
                  etiqueta: 'Tiempo',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Campo de nombre
          Text(
            'Nombre de la actividad',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controlador,
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(
              hintText: 'Ej: Rodada del domingo',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),

          // Botón guardar
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onGuardar,
              child: const Text('Guardar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearTiempo(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s}s';
  }
}

class _ResumenStat extends StatelessWidget {
  final String valor;
  final String etiqueta;

  const _ResumenStat({required this.valor, required this.etiqueta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          valor,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          etiqueta,
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}
