// apps/mobile/lib/features/tracking/screens/tracking_screen.dart
// Pantalla de grabación — diseño Stitch 2025: mapa full-screen + bento metrics

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/services/tracking_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/gradient_button.dart';
import 'activity_summary_screen.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _mapController = MapController();
  bool _siguiendoUbicacion = true;

  // Colores actualizados con paleta Stitch 2025
  static const _colorGrabando = Color(0xFF006B2C);
  static const _colorPausado = Color(0xFF9D4300);
  static const _colorDetener = Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

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
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Mapa full-screen ──────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(4.6097, -74.0817),
              initialZoom: 16,
              minZoom: 5,
              maxZoom: 19,
              onMapEvent: (_) {
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
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🚴', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── Gradiente oscuro (no captura eventos táctiles) ────
          IgnorePointer(
            child: Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.2, 0.6, 1.0],
                    colors: [
                      const Color(0xFF0F172A).withOpacity(0.55),
                      Colors.transparent,
                      Colors.transparent,
                      const Color(0xFF0F172A).withOpacity(0.95),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Header con blur ───────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: const Color(0xFF0F172A).withOpacity(0.75),
                  padding: EdgeInsets.fromLTRB(24, topInset + 12, 24, 12),
                  child: Row(
                    children: [
                      _IndicadorEstado(estado: tracking.estado),
                      const SizedBox(width: 10),
                      Text(
                        _tituloSegunEstado(tracking.estado),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bento metrics ─────────────────────────────────────
          Positioned(
            top: topInset + 64,
            left: 16,
            right: 16,
            child: _BentoMetrics(tracking: tracking),
          ),

          // ── Controles inferiores: FABs + GPS chip + CTA ───────
          Positioned(
            bottom: bottomInset + 88, // por encima del bottom nav
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      children: [
                        _MapFabButton(
                          icon: Icons.my_location,
                          active: _siguiendoUbicacion,
                          onTap: _centrarEnUbicacion,
                        ),
                        const SizedBox(height: 10),
                        _MapFabButton(
                          icon: Icons.layers_outlined,
                          active: false,
                          onTap: () {},
                        ),
                      ],
                    ),
                    _GpsChip(grabando: tracking.estaGrabando),
                  ],
                ),
                const SizedBox(height: 14),
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
          ),
        ],
      ),
    );
  }

  // ─── Acciones ──────────────────────────────────────────────────

  Future<void> _iniciarGrabacion() async {
    final tracking = context.read<TrackingService>();
    await tracking.iniciarGrabacion();
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
            style: ElevatedButton.styleFrom(backgroundColor: _colorDetener),
            child: const Text('Detener'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;
    await _mostrarModalGuardar(context, tracking);
  }

  Future<void> _mostrarModalGuardar(
    BuildContext context,
    TrackingService tracking,
  ) async {
    // Navegar a la pantalla completa de resumen de actividad
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ActivitySummaryScreen(),
      ),
    );
  }

  String _sugerirNombreActividad() {
    final hora = DateTime.now().hour;
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

// ─── Indicador de estado (punto animado) ──────────────────────────

class _IndicadorEstado extends StatelessWidget {
  final TrackingEstado estado;
  const _IndicadorEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      TrackingEstado.idle => Colors.grey,
      TrackingEstado.recording => const Color(0xFF62DF7D),
      TrackingEstado.paused => const Color(0xFFFD761A),
    };

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: estado == TrackingEstado.recording
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2)]
            : null,
      ),
    );
  }
}

// ─── Bento metrics grid ────────────────────────────────────────────

class _BentoMetrics extends StatelessWidget {
  final TrackingService tracking;
  const _BentoMetrics({required this.tracking});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tiempo — tarjeta grande
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TIEMPO DE GRABACIÓN',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: Color(0xFF62DF7D),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatearTiempo(tracking.tiempoTranscurrido),
                style: const TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Fila 1: Distancia + Desnivel
        Row(
          children: [
            Expanded(
              child: _GlassCard(
                child: _MetricCell(
                  label: 'DISTANCIA',
                  value: tracking.distanciaTotalKm.toStringAsFixed(1),
                  unit: 'KM',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GlassCard(
                child: _MetricCell(
                  label: 'DESNIVEL',
                  value: '--',
                  unit: 'M',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Fila 2: Velocidad prom. + Calorías
        Row(
          children: [
            Expanded(
              child: _GlassCard(
                child: _MetricCell(
                  label: 'VEL. PROM.',
                  value: tracking.velocidadPromedioKmh.toStringAsFixed(1),
                  unit: 'KM/H',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GlassCard(
                child: _MetricCell(
                  label: 'QUEMADAS',
                  value: '--',
                  unit: 'KCAL',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatearTiempo(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ─── Tarjeta con efecto vidrio ─────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF020617).withOpacity(0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Celda de métrica ──────────────────────────────────────────────

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _MetricCell({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Botón flotante del mapa ───────────────────────────────────────

class _MapFabButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _MapFabButton({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF020617).withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Icon(
              icon,
              size: 20,
              color: active ? const Color(0xFF62DF7D) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Chip señal GPS ────────────────────────────────────────────────

class _GpsChip extends StatefulWidget {
  final bool grabando;
  const _GpsChip({required this.grabando});

  @override
  State<_GpsChip> createState() => _GpsChipState();
}

class _GpsChipState extends State<_GpsChip> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const chipColor = Color(0xFFFD761A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _opacity,
            builder: (_, __) => Opacity(
              opacity: _opacity.value,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: chipColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'SEÑAL GPS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Panel de controles ────────────────────────────────────────────

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
    return switch (tracking.estado) {
      TrackingEstado.idle => GradientButton(
          label: 'Iniciar grabación',
          leading: const Icon(Icons.radio_button_checked, color: Colors.white, size: 20),
          onPressed: onIniciar,
        ),
      TrackingEstado.recording => Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: onPausar,
                  icon: const Icon(Icons.pause_rounded),
                  label: const Text('Pausar', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorPausado,
                    side: BorderSide(color: colorPausado, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              width: 56,
              child: ElevatedButton(
                onPressed: onDetener,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorDetener,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.stop_rounded, size: 28),
              ),
            ),
          ],
        ),
      TrackingEstado.paused => Row(
          children: [
            Expanded(
              child: GradientButton(
                label: 'Reanudar',
                leading: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                onPressed: onReanudar,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              width: 56,
              child: ElevatedButton(
                onPressed: onDetener,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorDetener,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.stop_rounded, size: 28),
              ),
            ),
          ],
        ),
    };
  }
}

// ─── Modal guardar actividad ───────────────────────────────────────

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
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 8),
              Text(
                'Guardar actividad',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
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
          Text(
            'Nombre de la actividad',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
          GradientButton(label: 'Guardar', onPressed: onGuardar),
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
        Text(valor, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        Text(etiqueta, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}
