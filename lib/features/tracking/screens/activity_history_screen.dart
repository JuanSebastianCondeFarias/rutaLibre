// apps/mobile/lib/features/tracking/screens/activity_history_screen.dart
// Pantalla de historial de actividades grabadas con detalle y mapa del recorrido

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/tracking_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../models/activity_record.dart';

/// Pantalla de historial de actividades.
///
/// Lista todas las actividades guardadas en Hive ordenadas por fecha descendente.
/// Permite ver el detalle con mapa del recorrido y eliminar actividades.
class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  List<ActivityRecord>? _actividades;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarActividades();
  }

  Future<void> _cargarActividades() async {
    setState(() => _cargando = true);
    final tracking = context.read<TrackingService>();
    final lista = await tracking.cargarActividades();
    if (mounted) {
      setState(() {
        _actividades = lista;
        _cargando = false;
      });
    }
  }

  Future<void> _eliminarActividad(ActivityRecord actividad) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: Text(
          '¿Eliminar "${actividad.title}"? Esta acción no se puede deshacer.',
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final tracking = context.read<TrackingService>();
    await tracking.eliminarActividad(actividad.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Actividad eliminada')),
      );
      _cargarActividades();
    }
  }

  void _abrirDetalle(ActivityRecord actividad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ActivityDetailScreen(actividad: actividad),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis actividades'),
        actions: [
          // Botón de recarga manual
          IconButton(
            onPressed: _cargarActividades,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _buildContenido(theme),
    );
  }

  Widget _buildContenido(ThemeData theme) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final actividades = _actividades ?? [];

    if (actividades.isEmpty) {
      return _EstadoVacio();
    }

    return RefreshIndicator(
      onRefresh: _cargarActividades,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: actividades.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _ActividadCard(
          actividad: actividades[i],
          onTap: () => _abrirDetalle(actividades[i]),
          onEliminar: () => _eliminarActividad(actividades[i]),
        ),
      ),
    );
  }
}

// ─── Widgets internos ──────────────────────────────────────────

/// Tarjeta de resumen de una actividad en la lista.
class _ActividadCard extends StatelessWidget {
  final ActivityRecord actividad;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  const _ActividadCard({
    required this.actividad,
    required this.onTap,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fechaFormato = DateFormat('EEE d MMM, HH:mm', 'es_CO');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera: título + botón eliminar
              Row(
                children: [
                  const Icon(
                    Icons.directions_bike,
                    size: 18,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      actividad.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: onEliminar,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: theme.colorScheme.error,
                    tooltip: 'Eliminar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),

              // Fecha
              Text(
                fechaFormato.format(actividad.startedAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),

              // Stats en fila
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniStat(
                    icono: Icons.straighten,
                    valor: '${actividad.distanceKm.toStringAsFixed(2)} km',
                    etiqueta: 'Distancia',
                  ),
                  _MiniStat(
                    icono: Icons.timer_outlined,
                    valor: actividad.duracionFormateada,
                    etiqueta: 'Tiempo',
                  ),
                  _MiniStat(
                    icono: Icons.speed,
                    valor: '${actividad.avgSpeedKmh.toStringAsFixed(1)} km/h',
                    etiqueta: 'Promedio',
                  ),
                  // Indicador de ciudad
                  _MiniStat(
                    icono: Icons.location_city,
                    valor: actividad.citySlug,
                    etiqueta: 'Ciudad',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;

  const _MiniStat({
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: theme.colorScheme.primary),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

/// Estado vacío con ilustración y mensaje motivacional.
class _EstadoVacio extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ilustración simple con icono grande
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🚴', style: TextStyle(fontSize: 52)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aún no tienes actividades',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sale a rodar y graba tu primera aventura ciclista en Bogotá.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pantalla de detalle ───────────────────────────────────────

/// Pantalla de detalle de una actividad: mapa del recorrido + stats completas.
class _ActivityDetailScreen extends StatelessWidget {
  final ActivityRecord actividad;

  const _ActivityDetailScreen({required this.actividad});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final theme = Theme.of(context);
    final fechaFormato = DateFormat("EEEE d 'de' MMMM yyyy, HH:mm", 'es_CO');

    // Convertir puntos del registro a LatLng para el mapa
    final puntos = actividad.points
        .map((p) => LatLng(p[0], p[1]))
        .toList();

    // Calcular centro del recorrido para enfocar el mapa
    final centroMapa = puntos.isNotEmpty
        ? puntos[puntos.length ~/ 2]
        : const LatLng(4.6097, -74.0817);

    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          actividad.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Mapa del recorrido ──────────────────────────────
            SizedBox(
              height: 280,
              child: puntos.isNotEmpty
                  ? FlutterMap(
                      options: MapOptions(
                        initialCenter: centroMapa,
                        initialZoom: 14,
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
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: puntos,
                              strokeWidth: 5.0,
                              color: const Color(0xFF16A34A),
                            ),
                          ],
                        ),
                        // Marcadores de inicio y fin
                        if (puntos.length >= 2)
                          MarkerLayer(
                            markers: [
                              // Inicio
                              Marker(
                                point: puntos.first,
                                width: 32,
                                height: 32,
                                child: _PuntoMapa(
                                  color: const Color(0xFF16A34A),
                                  letra: 'A',
                                ),
                              ),
                              // Fin
                              Marker(
                                point: puntos.last,
                                width: 32,
                                height: 32,
                                child: _PuntoMapa(
                                  color: const Color(0xFFEF4444),
                                  letra: 'B',
                                ),
                              ),
                            ],
                          ),
                      ],
                    )
                  : Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: const Center(
                        child: Text('Sin puntos GPS grabados'),
                      ),
                    ),
            ),

            // ─── Stats completas ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fecha y ciudad
                  Text(
                    fechaFormato.format(actividad.startedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_city,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        actividad.citySlug.toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Grid de estadísticas principales
                  _GridStats(actividad: actividad),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marcador de inicio/fin en el mapa de detalle.
class _PuntoMapa extends StatelessWidget {
  final Color color;
  final String letra;

  const _PuntoMapa({required this.color, required this.letra});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          letra,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Grid 2x2 con las stats completas de la actividad.
class _GridStats extends StatelessWidget {
  final ActivityRecord actividad;

  const _GridStats({required this.actividad});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatData(
        icono: Icons.straighten,
        valor: '${actividad.distanceKm.toStringAsFixed(2)} km',
        etiqueta: 'Distancia total',
      ),
      _StatData(
        icono: Icons.timer_outlined,
        valor: actividad.duracionFormateada,
        etiqueta: 'Tiempo en ruta',
      ),
      _StatData(
        icono: Icons.speed,
        valor: '${actividad.avgSpeedKmh.toStringAsFixed(1)} km/h',
        etiqueta: 'Velocidad promedio',
      ),
      _StatData(
        icono: Icons.pin_drop_outlined,
        valor: '${actividad.points.length} pts',
        etiqueta: 'Puntos GPS',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: items.map((s) => _StatCard(data: s)).toList(),
    );
  }
}

class _StatData {
  final IconData icono;
  final String valor;
  final String etiqueta;

  const _StatData({
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });
}

class _StatCard extends StatelessWidget {
  final _StatData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(data.icono, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.valor,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  data.etiqueta,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
