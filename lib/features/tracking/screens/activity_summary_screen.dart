// lib/features/tracking/screens/activity_summary_screen.dart
// Pantalla de resumen y guardado de actividad — diseño editorial Stitch 2025

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/services/tracking_service.dart';
import '../../../core/theme/theme_provider.dart';

// ─── Constantes de paleta para el diseño dark editorial ────────
const _kBg = Color(0xFF0F172A); // slate-950
const _kSurface = Color(0xFF1E293B); // slate-800
const _kSurfaceHigh = Color(0xFF334155); // slate-700
const _kGreen = Color(0xFF22C55E); // green-500
const _kGreenDim = Color(0xFF16A34A); // green-600
const _kGreenGlow = Color(0x4022C55E); // verde con alpha
const _kText = Color(0xFFF7F9FB); // blanco suave
const _kTextMuted = Color(0xFF64748B); // slate-500
const _kTextSub = Color(0xFF94A3B8); // slate-400

/// Tipos de bicicleta disponibles para etiquetar la actividad.
enum _TipoBici { gravel, urbana, ruta }

/// Pantalla completa de resumen de actividad al finalizar la grabación.
///
/// Recibe los datos del [TrackingService] y permite al usuario nombrar,
/// describir y etiquetar la actividad antes de guardarla.
class ActivitySummaryScreen extends StatefulWidget {
  const ActivitySummaryScreen({super.key});

  @override
  State<ActivitySummaryScreen> createState() => _ActivitySummaryScreenState();
}

class _ActivitySummaryScreenState extends State<ActivitySummaryScreen> {
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  _TipoBici _tipoBici = _TipoBici.urbana;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text = _sugerirNombre();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  String _sugerirNombre() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Rodada matutina';
    if (hora < 17) return 'Rodada de la tarde';
    return 'Rodada nocturna';
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Contenido scrollable ─────────────────────────────
          CustomScrollView(
            slivers: [
              // Header fijo con blur
              _SliverHeader(
                onCerrar: () => Navigator.of(context).pop(),
                onGuardar: _guardando ? null : () => _guardar(tracking),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 1. Preview del mapa con la ruta
                    _MapaPreview(
                      puntos: tracking.puntos,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),

                    // 2. Grid de estadísticas (bento)
                    _StatsGrid(
                      distanciaKm: tracking.distanciaTotalKm,
                      duracion: tracking.tiempoTranscurrido,
                      velocidadPromedio: tracking.velocidadPromedioKmh,
                      caloriasEst: _estimarCalorias(tracking.distanciaTotalKm),
                    ),
                    const SizedBox(height: 16),

                    // 3. Banner de gamificación
                    _BannerXP(
                      puntoGanados: _calcularXP(tracking.distanciaTotalKm),
                    ),
                    const SizedBox(height: 16),

                    // 4. Campos de texto
                    _CamposTexto(
                      nombreCtrl: _nombreCtrl,
                      descripcionCtrl: _descripcionCtrl,
                    ),
                    const SizedBox(height: 16),

                    // 5. Chips de tipo de bici
                    _ChipsTipoBici(
                      seleccionado: _tipoBici,
                      onSeleccionar: (t) => setState(() => _tipoBici = t),
                    ),
                    const SizedBox(height: 16),

                    // 6. Agregar fotos (placeholder)
                    _SeccionFotos(),
                  ]),
                ),
              ),
            ],
          ),

          // ── Botón inferior fijo ──────────────────────────────
          _BottomAction(
            guardando: _guardando,
            onGuardar: () => _guardar(tracking),
          ),
        ],
      ),
    );
  }

  int _estimarCalorias(double distanciaKm) => (distanciaKm * 42).round();

  int _calcularXP(double distanciaKm) {
    final base = (distanciaKm * 10).round();
    return base.clamp(10, 500);
  }

  Future<void> _guardar(TrackingService tracking) async {
    if (_guardando) return;
    setState(() => _guardando = true);

    try {
      final storage = context.read<StorageService>();
      await tracking.detener(
        title: _nombreCtrl.text.trim().isEmpty
            ? _sugerirNombre()
            : _nombreCtrl.text.trim(),
        citySlug: storage.ciudadSeleccionada,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Actividad guardada correctamente'),
          backgroundColor: _kGreenDim,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

// ─── Sliver: Header con blur ────────────────────────────────────

class _SliverHeader extends StatelessWidget {
  final VoidCallback onCerrar;
  final VoidCallback? onGuardar;

  const _SliverHeader({required this.onCerrar, required this.onGuardar});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xCC0F172A), // slate-950 con 80% opacidad
          ),
          child: FlexibleSpaceBar(
            background: Container(), // solo para activar el blur del sistema
          ),
        ),
      ),
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Botón cerrar
          _HeaderIconBtn(
            icon: Icons.close_rounded,
            onTap: onCerrar,
          ),
          const SizedBox(width: 12),
          Text(
            'Resumen de actividad',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onGuardar,
          child: Text(
            'Guardar',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _kGreen,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _kSurface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _kTextSub, size: 20),
      ),
    );
  }
}

// ─── Widget: Preview del mapa ───────────────────────────────────

class _MapaPreview extends StatelessWidget {
  final List<LatLng> puntos;
  final bool isDark;

  const _MapaPreview({required this.puntos, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Centro y bounds de la ruta
    LatLng centro = const LatLng(4.6097, -74.0817);
    if (puntos.isNotEmpty) {
      final latSum = puntos.map((p) => p.latitude).reduce((a, b) => a + b);
      final lngSum = puntos.map((p) => p.longitude).reduce((a, b) => a + b);
      centro = LatLng(latSum / puntos.length, lngSum / puntos.length);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            // Mapa base
            FlutterMap(
              options: MapOptions(
                initialCenter: centro,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none, // no interactivo en preview
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: isDark
                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains:
                      isDark ? const ['a', 'b', 'c', 'd'] : const ['a', 'b', 'c'],
                  userAgentPackageName: 'co.rutalibre.app',
                ),
                if (puntos.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: puntos.toList(),
                        strokeWidth: 4.0,
                        color: _kGreen,
                        strokeCap: StrokeCap.round,
                      ),
                    ],
                  ),
                // Marcador inicio y fin
                if (puntos.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      _marcadorRuta(puntos.first, isStart: true),
                      if (puntos.length > 1)
                        _marcadorRuta(puntos.last, isStart: false),
                    ],
                  ),
              ],
            ),

            // Degradado inferior
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      _kBg.withValues(alpha: 0.7),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Badge "Ruta grabada" abajo izquierda
            Positioned(
              bottom: 14,
              left: 16,
              child: _BadgeRutaGrabada(),
            ),

            // Botón fullscreen abajo derecha (placeholder)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kBg.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fullscreen_rounded,
                    color: _kText, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _marcadorRuta(LatLng punto, {required bool isStart}) {
    return Marker(
      point: punto,
      width: 16,
      height: 16,
      child: Container(
        decoration: BoxDecoration(
          color: isStart ? _kGreen : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isStart ? _kBg : _kGreen,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _BadgeRutaGrabada extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kGreenGlow,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
        // leve efecto de blur visual con opacidad
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded,
              color: _kGreen, size: 13),
          const SizedBox(width: 4),
          Text(
            'RUTA GRABADA',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _kGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widget: Grid de estadísticas ──────────────────────────────

class _StatsGrid extends StatelessWidget {
  final double distanciaKm;
  final Duration duracion;
  final double velocidadPromedio;
  final int caloriasEst;

  const _StatsGrid({
    required this.distanciaKm,
    required this.duracion,
    required this.velocidadPromedio,
    required this.caloriasEst,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatTile(
          icono: Icons.straighten_rounded,
          etiqueta: 'DISTANCIA',
          valor: distanciaKm.toStringAsFixed(1),
          unidad: 'km',
        ),
        _StatTile(
          icono: Icons.timer_outlined,
          etiqueta: 'DURACIÓN',
          valor: _formatDuracion(duracion),
          unidad: '',
        ),
        _StatTile(
          icono: Icons.speed_rounded,
          etiqueta: 'VEL. PROM.',
          valor: velocidadPromedio.toStringAsFixed(1),
          unidad: 'km/h',
        ),
        _StatTile(
          icono: Icons.local_fire_department_rounded,
          etiqueta: 'CALORÍAS EST.',
          valor: '$caloriasEst',
          unidad: 'kcal',
        ),
      ],
    );
  }

  String _formatDuracion(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _StatTile extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
  final String unidad;

  const _StatTile({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.unidad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icono, color: _kGreen, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _kTextMuted,
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: valor,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _kText,
                        height: 1.1,
                      ),
                    ),
                    if (unidad.isNotEmpty)
                      TextSpan(
                        text: ' $unidad',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: _kTextSub,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Widget: Banner de gamificación ────────────────────────────

class _BannerXP extends StatelessWidget {
  final int puntoGanados;

  const _BannerXP({required this.puntoGanados});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF052E16).withValues(alpha: 0.9), // green-950
            _kSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Ícono con glow
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kGreen,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _kGreen.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.military_tech_rounded,
                color: _kBg, size: 24),
          ),
          const SizedBox(width: 14),

          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Nivel completado!',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
                Text(
                  'Puntos ganados: +$puntoGanados XP',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _kGreen,
                  ),
                ),
              ],
            ),
          ),

          // Barra de progreso
          Column(
            children: [
              Text(
                '75%',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: _kTextMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  width: 56,
                  height: 6,
                  child: LinearProgressIndicator(
                    value: 0.75,
                    backgroundColor: _kSurfaceHigh,
                    valueColor: const AlwaysStoppedAnimation(_kGreen),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Widget: Campos de texto ────────────────────────────────────

class _CamposTexto extends StatelessWidget {
  final TextEditingController nombreCtrl;
  final TextEditingController descripcionCtrl;

  const _CamposTexto({
    required this.nombreCtrl,
    required this.descripcionCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabelSeccion('NOMBRE DE LA ACTIVIDAD'),
        const SizedBox(height: 8),
        _InputField(
          controller: nombreCtrl,
          hint: 'Ej: Rodada del domingo',
          maxLines: 1,
        ),
        const SizedBox(height: 16),
        _LabelSeccion('DESCRIPCIÓN'),
        const SizedBox(height: 8),
        _InputField(
          controller: descripcionCtrl,
          hint: '¿Cómo estuvo la rodada?',
          maxLines: 3,
        ),
      ],
    );
  }
}

class _LabelSeccion extends StatelessWidget {
  final String texto;
  const _LabelSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        texto,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: _kTextMuted,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(
        color: _kText,
        fontWeight: maxLines == 1 ? FontWeight.w600 : FontWeight.w400,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: _kTextMuted, fontSize: 14),
        filled: true,
        fillColor: _kSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kGreen, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}

// ─── Widget: Chips tipo de bicicleta ───────────────────────────

class _ChipsTipoBici extends StatelessWidget {
  final _TipoBici seleccionado;
  final ValueChanged<_TipoBici> onSeleccionar;

  const _ChipsTipoBici({
    required this.seleccionado,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabelSeccion('TIPO DE BICI'),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ChipBici(
                icono: Icons.terrain_rounded,
                etiqueta: 'Gravel',
                activo: seleccionado == _TipoBici.gravel,
                onTap: () => onSeleccionar(_TipoBici.gravel),
              ),
              const SizedBox(width: 10),
              _ChipBici(
                icono: Icons.location_city_rounded,
                etiqueta: 'Urbana',
                activo: seleccionado == _TipoBici.urbana,
                onTap: () => onSeleccionar(_TipoBici.urbana),
              ),
              const SizedBox(width: 10),
              _ChipBici(
                icono: Icons.speed_rounded,
                etiqueta: 'Ruta',
                activo: seleccionado == _TipoBici.ruta,
                onTap: () => onSeleccionar(_TipoBici.ruta),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChipBici extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  const _ChipBici({
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: activo ? _kGreen : _kSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 16,
              color: activo ? _kBg : _kTextSub,
            ),
            const SizedBox(width: 6),
            Text(
              etiqueta,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: activo ? _kBg : _kTextSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widget: Sección fotos ──────────────────────────────────────

class _SeccionFotos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabelSeccion('AGREGAR FOTOS'),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Botón agregar foto
              _BtnAgregarFoto(),
              // TODO: mostrar fotos seleccionadas aquí
            ],
          ),
        ),
      ],
    );
  }
}

class _BtnAgregarFoto extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: abrir image picker
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: _kSurface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _kSurfaceHigh,
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: _kTextMuted, size: 28),
            const SizedBox(height: 4),
            Text(
              'Foto',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: _kTextMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widget: Botón inferior fijo ────────────────────────────────

class _BottomAction extends StatelessWidget {
  final bool guardando;
  final VoidCallback onGuardar;

  const _BottomAction({required this.guardando, required this.onGuardar});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _kBg.withValues(alpha: 0.0),
              _kBg.withValues(alpha: 0.95),
              _kBg,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón principal
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: guardando ? null : onGuardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: _kBg,
                  disabledBackgroundColor: _kGreen.withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  shadowColor: _kGreen.withValues(alpha: 0.4),
                ).copyWith(
                  elevation: WidgetStateProperty.resolveWith(
                    (states) =>
                        states.contains(WidgetState.pressed) ? 0 : 8,
                  ),
                ),
                child: guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: _kBg,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Guardar y compartir',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _kBg,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.share_rounded,
                              color: _kBg, size: 20),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PUBLICAR EN FEED Y STRAVA',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: _kTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
